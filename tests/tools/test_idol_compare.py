"""#238 comparison harness: PLY facts, the gsplat camera conversion, conditions and metrics. No real PLY needed:
synthetic PLYs are written to a temp folder."""
import importlib.util
import json
import math
import os
import struct
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
IDOL = ROOT / "tools" / "assets" / "idol"
sys.path.insert(0, str(IDOL))
import ply_info  # noqa: E402

HAS_TORCH = importlib.util.find_spec("torch") is not None
BASE = ["x", "y", "z", "nx", "ny", "nz", "f_dc_0", "f_dc_1", "f_dc_2", "opacity", "scale_0", "scale_1", "scale_2",
        "rot_0", "rot_1", "rot_2", "rot_3"]


def write_ply(path, rows, names=BASE):
    with open(path, "wb") as f:
        f.write(b"ply\nformat binary_little_endian 1.0\nelement vertex %d\n" % len(rows))
        for n in names:
            f.write(b"property float %s\n" % n.encode())
        f.write(b"end_header\n")
        for r in rows:
            f.write(struct.pack("<%df" % len(names), *r))


def splat(x=0.0, y=0.0, z=0.0, opacity=4.0, scale=-3.0, extra=()):
    return [x, y, z, 0, 0, 0, 1.0, 0.5, 0.0, opacity, scale, scale, scale, 1, 0, 0, 0, *extra]


class PlyInfoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_degree_zero_file(self):
        p = os.path.join(self.tmp.name, "a.ply")
        write_ply(p, [splat(-0.5), splat(0.5, opacity=-6.0)])
        i = ply_info.info(p)
        self.assertEqual(i["splats"], 2)
        self.assertEqual(i["sh_degree"], 0)
        self.assertEqual(i["bbox_min"][0], -0.5)
        self.assertEqual(i["bbox_max"][0], 0.5)
        self.assertEqual(i["opacity_below_0.04"], 0.5)   # sigmoid(-6) = 0.0025
        self.assertEqual(len(i["sha256"]), 64)

    def test_degree_three_file(self):
        names = BASE + ["f_rest_%d" % k for k in range(45)]
        p = os.path.join(self.tmp.name, "b.ply")
        write_ply(p, [splat(extra=[0.0] * 45)], names)
        self.assertEqual(ply_info.info(p)["sh_degree"], 3)

    def test_odd_rest_count_is_an_error(self):
        with self.assertRaises(ValueError):
            ply_info.sh_degree(BASE + ["f_rest_%d" % k for k in range(10)])

    def test_ascii_ply_is_refused(self):
        p = os.path.join(self.tmp.name, "c.ply")
        Path(p).write_bytes(b"ply\nformat ascii 1.0\nelement vertex 0\nend_header\n")
        with self.assertRaises(ValueError):
            ply_info.header(p)


@unittest.skipUnless(HAS_TORCH, "torch not installed")
class HarnessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import torch
        import splat_backends
        import splat_compare
        import splat_render
        cls.torch, cls.B, cls.C, cls.S = torch, splat_backends, splat_compare, splat_render

    def test_gsplat_camera_maps_points_like_J(self):
        torch = self.torch
        J, view, origin = self.C.raw_camera()
        vm, K = self.B.camera(J, view, origin)
        p = torch.randn(50, 3, device=J.device)
        cam = p @ vm[:3, :3].T + vm[:3, 3]
        uv = cam[:, :2] * K.diagonal()[:2] + K[:2, 2]                # gsplat ortho: fx * x + cx (pixel i centre at i + 0.5)
        want = p @ J.T + torch.tensor(origin, device=J.device) + 0.5
        self.assertLess(float((uv - want).abs().max()), 1e-3)
        self.assertGreater(float(cam[:, 2].min()), -10.0)       # in front once the offset is applied

    def test_skewed_camera_is_refused(self):
        torch = self.torch
        with self.assertRaises(ValueError):
            self.B.camera(torch.tensor([[1.0, 0, 0], [0.5, 1, 0]]), torch.tensor([0, 0, 1.0]), (0, 0))

    def test_current_samples_pixel_i_at_i(self):
        torch = self.torch
        S = self.S
        g = {"xyz": torch.zeros(1, 3, device=S.DEV), "cov": torch.eye(3, device=S.DEV)[None] * 1e-6,
             "rgb": torch.ones(1, 3, device=S.DEV), "alpha": torch.ones(1, device=S.DEV)}
        J = torch.tensor([[1.0, 0, 0], [0, 1.0, 0]], device=S.DEV)
        img = S.rasterize(g, J, torch.tensor([0, 0, 1.0], device=S.DEV), (5, 5), (11, 11))
        self.assertEqual(np.unravel_index(img[..., 3].argmax(), img.shape[:2]), (5, 5))
        same = S.rasterize(g, J, torch.tensor([0, 0, 1.0], device=S.DEV), (5, 5), (11, 11), dilation=0.3)
        self.assertTrue((img == same).all())                   # the default is the old fixed +0.3

    def test_fixture_options_read_fixtures_json(self):
        cfg = json.loads((IDOL / "fixtures.json").read_text(encoding="utf-8"))
        o = self.C.fixture_options(cfg["warmer_oden"])
        self.assertEqual(o["glass_above"], 0.34)
        self.assertEqual(o["drop_above"], 0.68)
        self.assertEqual(o["backend"], "current")
        self.assertTrue(self.C.applicable("no_glass_split", o))
        self.assertFalse(self.C.applicable("no_cutaway", o))     # warmer_oden has no cutaway to turn off
        self.assertTrue(self.C.applicable("baseline", o))

    def test_metrics_diff(self):
        a = np.zeros((4, 4, 4), np.uint8)
        a[1:3, 1:3] = 255
        b = a.copy()
        b[1, 1] = 0
        m = self.C.metrics(b, a)
        self.assertEqual(m["coverage_px"], 3)
        self.assertEqual(m["diff_px_over_8"], 1)
        self.assertEqual(m["diff_alpha_px_over_8"], 1)


if __name__ == "__main__":
    unittest.main()
