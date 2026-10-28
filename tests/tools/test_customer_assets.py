"""Unit tests for the customer sprite gate (Issue #23): PASS on the committed assets, FAIL on tampered copies."""
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import unittest

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "assets"))
import figures  # noqa: E402
import validate_customers as vc  # noqa: E402

ASSETS = os.path.join(ROOT, "assets", "generated", "characters")


def run(directory):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = vc.main(["--dir", directory])
    return code, out.getvalue()


def errors(directory, vid):
    """Problems of one variant's manifest (the whole-folder rules need all variants; see run_tests.ps1)."""
    r = vc.manifest_errors(os.path.join(directory, vid, "%s.character.json" % vid))
    return "\n".join(r if isinstance(r, list) else r[0])


# The committed assets themselves are checked by tools/run_tests.ps1 (validate_customers.py on the real folder).
class CustomerAssets(unittest.TestCase):
    # Only the variants the tests tamper with (and the calibration) are copied: decoding every frame of every
    # variant took about 6 s per test.
    VARIANTS = ("customer_a", "customer_b", "customer_c")

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.dir = os.path.join(self.tmp, "characters")
        os.makedirs(self.dir)
        for t in self.VARIANTS + ("calibration",):
            shutil.copytree(os.path.join(ASSETS, t), os.path.join(self.dir, t))
        shutil.copy(os.path.join(ASSETS, "PROVENANCE.json"), self.dir)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def manifest(self, vid="customer_a"):
        return os.path.join(self.dir, vid, "%s.character.json" % vid)

    def test_the_untouched_copies_pass(self):
        for vid in self.VARIANTS:
            self.assertEqual(errors(self.dir, vid), "", vid)

    def test_frame_counts_match_the_contract(self):
        self.assertEqual(figures.ANIMS, {"walk": 6, "idle": 2, "inspect": 4})
        with open(self.manifest(), encoding="utf-8") as f:
            m = json.load(f)
        for d in range(4):
            for anim, n in figures.ANIMS.items():
                self.assertEqual(len(m["directions"][str(d)][anim]), n)
        self.assertEqual(len(figures.VARIANTS), 3)

    def test_missing_frame_fails(self):
        os.remove(os.path.join(self.dir, "customer_a", "d1_walk_f3.png"))
        self.assertIn("d1_walk_f3.png missing", errors(self.dir, "customer_a"))

    def test_wrong_canvas_fails(self):
        path = os.path.join(self.dir, "customer_b", "d2_idle_f0.png")
        Image.new("RGBA", (50, 60), (255, 0, 0, 255)).save(path)
        self.assertIn("manifest says", errors(self.dir, "customer_b"))

    def test_shifted_anchor_fails_height_check(self):
        with open(self.manifest("customer_c"), encoding="utf-8") as f:
            m = json.load(f)
        m["anchor_px"][1] += 40
        with open(self.manifest("customer_c"), "w", encoding="utf-8") as f:
            json.dump(m, f)
        self.assertIn("head top rows", errors(self.dir, "customer_c"))

    def test_bad_frame_rate_fails(self):
        with open(self.manifest(), encoding="utf-8") as f:
            m = json.load(f)
        m["animations"]["walk"]["fps"] = 30
        with open(self.manifest(), "w", encoding="utf-8") as f:
            json.dump(m, f)
        self.assertIn("animation walk", errors(self.dir, "customer_a"))

    def test_calibration_is_required(self):
        os.remove(os.path.join(self.dir, "calibration", "iso2x_v1_calibration.png"))
        with open(os.path.join(self.dir, "PROVENANCE.json"), encoding="utf-8") as f:
            prov = json.load(f)
        self.assertIn("calibration image missing", "\n".join(vc.vm.calibration_errors(prov, self.dir)))

    def test_four_facings_are_rendered_rotations_not_mirrors(self):
        # East and west views of an asymmetric figure (shoulder bag on one side) must differ in more than a flip.
        a = Image.open(os.path.join(ASSETS, "customer_b", "d0_idle_f0.png")).convert("RGBA")
        b = Image.open(os.path.join(ASSETS, "customer_b", "d2_idle_f0.png")).convert("RGBA")
        self.assertNotEqual(a.tobytes(), b.transpose(Image.FLIP_LEFT_RIGHT).tobytes())


if __name__ == "__main__":
    unittest.main()
