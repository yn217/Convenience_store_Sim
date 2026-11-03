"""Interchangeable orthographic splat rasterizers for the #238 A/B comparison. Each takes the splat_render.py inputs
(g = {xyz, cov, rgb, alpha} in world units, J [2,3] world -> screen px, view [3] towards the camera, origin px, size)
and returns straight-alpha RGBA uint8, so the same scene and camera go to every backend unchanged.

    current         splat_render.rasterize as it is (max_radius 48, +0.3 px^2 dilation)
    current_r256    the same with max_radius 256 (no clipping of large splats in practice)
    current_nodil   the same with no dilation
    gsplat_classic  nerfstudio-project/gsplat, camera_model "ortho", rasterize_mode "classic" (eps2d 0.3)
    gsplat_aa       the same, rasterize_mode "antialiased" (eps2d 0.3 with the opacity compensation of Mip-Splatting)

gsplat (Apache-2.0) runs only in its own venv (F:/AI_Tools/gsplat-venv: Python 3.10, torch 2.4.1+cu124,
gsplat 1.5.3+pt24cu124); splat_render.py runs in both, so the comparison uses that venv for all backends.
"""
import os
import sys

import numpy as np
import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import splat_render as S  # noqa: E402


def camera(J: torch.Tensor, view: torch.Tensor, origin, depth_offset: float = 10.0):
    """J, view, origin -> (viewmat [4,4], K [3,3]) of an orthographic gsplat camera that maps a world point to the
    same screen px as splat_render. J's rows must be orthogonal and of one length (an orthographic camera with square
    pixels: every view of the pipeline is). gsplat samples pixel i at i + 0.5 and splat_render at i, so the principal
    point moves by half a pixel. depth_offset puts every splat in front of the near plane (camera z > 0)."""
    s0, s1 = float(J[0].norm()), float(J[1].norm())
    if abs(s0 - s1) > 1e-3 * s0 or abs(float(J[0] @ J[1])) > 1e-3 * s0 * s1:
        raise ValueError("J is not an orthographic camera with square pixels")
    rot = torch.stack([J[0] / s0, J[1] / s1, -view / view.norm()])
    vm = torch.eye(4, device=J.device)
    vm[:3, :3] = rot
    vm[2, 3] = depth_offset
    K = torch.tensor([[s0, 0.0, origin[0] + 0.5], [0.0, s1, origin[1] + 0.5], [0.0, 0.0, 1.0]], device=J.device)
    return vm, K


def _gsplat(g, J, view, origin, size, mode):
    from gsplat import rasterization
    vm, K = camera(J, view, origin)
    depth = -(g["xyz"] @ view)
    vm[2, 3] = float(-depth.min()) + 1.0
    w, h = size
    colors, alphas, _ = rasterization(
        g["xyz"].contiguous(), None, None, g["alpha"].contiguous(), g["rgb"].contiguous(),
        vm[None], K[None], w, h, covars=g["cov"].contiguous(), camera_model="ortho", rasterize_mode=mode,
        eps2d=0.3, near_plane=0.0, sh_degree=None, packed=False)
    a = alphas[0]
    rgb = colors[0] / a.clamp_min(1e-6)   # premultiplied -> straight
    out = torch.cat([rgb, a], -1).clamp(0, 1)
    return (out * 255 + 0.5).byte().cpu().numpy()


BACKENDS = {
    "current": lambda g, J, v, o, s: S.rasterize(g, J, v, o, s),
    "current_r256": lambda g, J, v, o, s: S.rasterize(g, J, v, o, s, max_radius=256),
    "current_nodil": lambda g, J, v, o, s: S.rasterize(g, J, v, o, s, dilation=0.0),
    "gsplat_classic": lambda g, J, v, o, s: _gsplat(g, J, v, o, s, "classic"),
    "gsplat_aa": lambda g, J, v, o, s: _gsplat(g, J, v, o, s, "antialiased"),
}


def available() -> list:
    names = [n for n in BACKENDS if n.startswith("current")]
    try:
        import gsplat  # noqa: F401
        names += [n for n in BACKENDS if n.startswith("gsplat")]
    except ImportError:
        pass
    return names


def straight_to_premult(img: np.ndarray) -> np.ndarray:
    f = img.astype(np.float32) / 255.0
    f[..., :3] *= f[..., 3:4]
    return f
