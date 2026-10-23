"""Unit tests for the asset pipeline tools (Issue #8). Run: python -m unittest discover -s tests/tools -v

They never need Blender: the validator must PASS the committed assets and must FAIL on
tampered copies (missing file, shifted anchor, rescaled sprite, wrong canvas, bad calibration...).
"""
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "assets"))
import blueprints  # noqa: E402
import iso2x  # noqa: E402
import validate_manifests as vm  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "generated", "fixtures")
CATALOG = os.path.join(ROOT, "data", "fixtures", "mvp_v1.json")


def run_validator(directory):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = vm.main(["--dir", directory, "--catalog", CATALOG])
    return code, out.getvalue()


def catalog():
    with open(CATALOG, encoding="utf-8") as f:
        return {d["type_id"]: d for d in json.load(f)}


class Goldens(unittest.TestCase):
    def test_projection_goldens(self):
        self.assertEqual(iso2x.project(1, 0, 0), (128.0, 64.0))
        self.assertEqual(iso2x.project(0, 1, 0), (-128.0, 64.0))
        u, v = iso2x.project(0, 0, 1)
        self.assertEqual(u, 0.0)
        self.assertAlmostEqual(v, -156.76734354)

    def test_rotation_and_origin_cell(self):
        # 10_TEST_VECTORS A: a 1x2 turned 90 degrees covers 2x1 starting at the same min cell.
        self.assertEqual(iso2x.rotated_footprint_rect(1, 2, 0), (-0.5, -0.5, 0.5, 1.5))
        self.assertEqual(iso2x.rotated_footprint_rect(1, 2, 1), (-0.5, -0.5, 1.5, 0.5))
        self.assertEqual(iso2x.rotated_footprint_rect(1, 2, 2), (-0.5, -0.5, 0.5, 1.5))
        self.assertEqual(iso2x.rotated_footprint_rect(1, 2, 3), (-0.5, -0.5, 1.5, 0.5))
        for r in range(4):
            self.assertEqual(iso2x.rotated_footprint_rect(2, 2, r), (-0.5, -0.5, 1.5, 1.5))
        self.assertEqual(iso2x.transform_point(0, 0, 1, 2, 1), (1.0, 0.0))   # cell (0,0) -> (h-1-v, u) = (1, 0)

    def test_four_turns_return_to_the_start(self):
        for p in ((0.3, -0.2), (1.0, 2.0), (-0.5, 0.5)):
            q = p
            for _ in range(4):
                q = iso2x.rotate_point(q[0], q[1], 1)
            self.assertAlmostEqual(q[0], p[0])
            self.assertAlmostEqual(q[1], p[1])
        self.assertEqual([iso2x.rotate_edge("E", r) for r in range(4)], ["E", "S", "W", "N"])

    def test_blueprints_obey_the_size_contract(self):
        cat = catalog()
        for t in blueprints.supported_types():
            self.assertEqual(blueprints.problems(cat[t]), [], t)

    def test_blueprint_check_catches_an_oversized_model(self):
        d = dict(catalog()["shelf_general"])
        d["dimensions_m"] = dict(d["dimensions_m"], height=1.2)
        self.assertTrue(any("height" in p for p in blueprints.problems(d)))


class CommittedAssets(unittest.TestCase):
    def test_committed_assets_pass(self):
        code, out = run_validator(ASSETS)
        self.assertEqual(code, 0, out)

    def test_every_manifest_has_all_four_rotations_and_layers(self):
        for t in blueprints.supported_types():
            with open(os.path.join(ASSETS, t, "%s_a.visual.json" % t), encoding="utf-8") as f:
                m = json.load(f)
            self.assertEqual(sorted(m["rotations"]), ["0", "1", "2", "3"])
            for rot in m["rotations"].values():
                self.assertIn("body", rot["layers"])
                self.assertIn("shadow", rot["layers"])
                sizes = set()
                for f in rot["layers"].values():
                    with Image.open(os.path.join(ASSETS, t, f)) as im:
                        sizes.add(im.size)
                self.assertEqual(len(sizes), 1, "all layers of one direction share one canvas")

    def test_canvas_sizes_differ_between_assets(self):
        sizes = set()
        for t in blueprints.supported_types():
            with open(os.path.join(ASSETS, t, "%s_a.visual.json" % t), encoding="utf-8") as f:
                sizes.add(tuple(json.load(f)["rotations"]["0"]["canvas_px"]))
        self.assertGreater(len(sizes), 1, "unified physical scale, not unified image size")


class Tampering(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.dir = os.path.join(self.tmp, "fixtures")
        shutil.copytree(ASSETS, self.dir)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def manifest(self, t="shelf_general"):
        return os.path.join(self.dir, t, "%s_a.visual.json" % t)

    def edit(self, fn, t="shelf_general"):
        path = self.manifest(t)
        with open(path, encoding="utf-8") as f:
            m = json.load(f)
        fn(m)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(m, f)

    def assertFails(self, needle):
        code, out = run_validator(self.dir)
        self.assertEqual(code, 1, out)
        self.assertIn(needle, out)

    def test_missing_layer_file_is_detected(self):
        os.remove(os.path.join(self.dir, "shelf_general", "shelf_general_2_shadow.png"))
        self.assertFails("file missing")

    def test_shifted_anchor_is_detected(self):
        self.edit(lambda m: m["rotations"]["1"].update(anchor_px=[m["rotations"]["1"]["anchor_px"][0] + 6, m["rotations"]["1"]["anchor_px"][1]]))
        self.assertFails("edge")

    def test_per_asset_rescaling_is_detected(self):
        path = os.path.join(self.dir, "warmer_oden", "warmer_oden_0_body.png")
        img = Image.open(path)
        scaled = img.resize((int(img.width * 1.1), int(img.height * 1.1)))
        canvas = Image.new("RGBA", img.size, (0, 0, 0, 0))
        canvas.paste(scaled, (-10, -20))
        canvas.save(path)
        self.assertFails("edge")

    def test_wrong_canvas_size_is_detected(self):
        self.edit(lambda m: m["rotations"]["0"].update(canvas_px=[10, 10]))
        self.assertFails("canvas_px")

    def test_unsafe_layer_path_is_detected(self):
        self.edit(lambda m: m["rotations"]["0"]["layers"].update(body="../escape.png"))
        self.assertFails("unsafe")

    def test_unknown_field_is_detected(self):
        self.edit(lambda m: m.update(extra=1))
        self.assertFails("unknown field")

    def test_missing_rotation_is_detected(self):
        self.edit(lambda m: m["rotations"].pop("3"))
        self.assertFails("four rotations")

    def test_catalog_mismatch_is_detected(self):
        self.edit(lambda m: m.update(footprint={"w": 2, "h": 2}))
        self.assertFails("footprint")

    def test_rgb_png_without_alpha_is_detected(self):
        path = os.path.join(self.dir, "shelf_general", "shelf_general_0_body.png")
        Image.open(path).convert("RGB").save(path)
        self.assertFails("RGBA")

    def test_uncalibrated_camera_is_detected(self):
        path = os.path.join(self.dir, "calibration", "iso2x_v1_calibration.png")
        arr = np.array(Image.open(path).convert("RGBA"))
        red = (arr[..., 0] > 200) & (arr[..., 1] < 60) & (arr[..., 2] < 60) & (arr[..., 3] > 200)
        ys, xs = np.nonzero(red)
        arr[red] = 0
        arr[ys, np.clip(xs + 9, 0, arr.shape[1] - 1)] = (255, 0, 0, 255)   # X marker 9 px off
        Image.fromarray(arr, "RGBA").save(path)
        self.assertFails("calibration marker_x")

    def test_missing_calibration_blocks_everything(self):
        os.remove(os.path.join(self.dir, "calibration", "iso2x_v1_calibration.png"))
        self.assertFails("calibration image missing")

    def test_oversized_blender_mesh_is_detected(self):
        path = os.path.join(self.dir, "PROVENANCE.json")
        with open(path, encoding="utf-8") as f:
            prov = json.load(f)
        prov["mesh_bbox"]["shelf_general"]["0"]["max"][2] += 0.3
        with open(path, "w", encoding="utf-8") as f:
            json.dump(prov, f)
        self.assertFails("height")

    def test_padding_violation_is_detected(self):
        path = os.path.join(self.dir, "warmer_oden", "warmer_oden_0_body.png")
        arr = np.array(Image.open(path).convert("RGBA"))
        arr[0, 0] = (255, 255, 255, 255)       # a stray opaque pixel in the corner
        Image.fromarray(arr, "RGBA").save(path)
        self.assertFails("padding")


if __name__ == "__main__":
    unittest.main()
