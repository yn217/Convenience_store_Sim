"""Pixal3D single-view pilot runner (convenience store fixtures).

Wraps the official inference.py with three local changes, nothing else:
  - DINOv3 ViT-L/16 is loaded from the user-supplied local folder (no mirror download);
  - the RMBG-2.0 background remover is never loaded (non-commercial licence); inputs are already RGBA cutouts;
  - the camera FOV is given manually (MoGe is not installed).
"""
import argparse
import json
import os
import sys
import time

UPSTREAM = "/mnt/f/WSL/Pixal3D-upstream"
DINO = os.path.expanduser("~/pixal3d-models/dinov3-vitl16-pretrain-lvd1689m")   # copy of F:/Cordex_OpenAI/img_to_3D/...
sys.path.insert(0, UPSTREAM)
os.environ.setdefault("ATTN_BACKEND", "sdpa")

import torch  # noqa: E402
import pixal3d.pipelines.rembg as rembg_mod  # noqa: E402


class _NoRembg:
    """Stands in for BiRefNet/RMBG-2.0; inputs carry their own alpha, so it must never be called."""
    def __init__(self, *a, **k):
        pass

    def to(self, *a, **k):
        return self

    def cpu(self):
        return self

    def cuda(self):
        return self

    def __call__(self, *a, **k):
        raise RuntimeError("input image has no alpha; background removal is disabled in this pilot")


rembg_mod.BiRefNet = _NoRembg

import inference  # noqa: E402

for cfg in inference.IMAGE_COND_CONFIGS.values():
    cfg["model_name"] = DINO

# load the models once for every image (run_inference would reload ~25 GB per image)
_init_pipeline = inference.init_pipeline
_cache = {}


def _cached_init(model_path, device="cuda", low_vram=False):
    key = (model_path, device, low_vram)
    if key not in _cache:
        _cache[key] = _init_pipeline(model_path, device=device, low_vram=low_vram)
    return _cache[key]


inference.init_pipeline = _cached_init


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model_path", required=True)
    ap.add_argument("--out_dir", required=True)
    ap.add_argument("--fov", type=float, default=0.2)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--resolution", type=int, default=1024)
    ap.add_argument("--low_vram", action="store_true")
    ap.add_argument("images", nargs="+")
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    report = []
    for img in a.images:
        name = os.path.splitext(os.path.basename(img))[0]
        out = os.path.join(a.out_dir, name + ".glb")
        torch.cuda.reset_peak_memory_stats()
        t0 = time.time()
        inference.run_inference(image_path=img, output_path=out, seed=a.seed, manual_fov=a.fov,
                                model_path=a.model_path, low_vram=a.low_vram, resolution=a.resolution)
        rec = {"name": name, "glb": out, "seconds": round(time.time() - t0, 1),
               "peak_gpu_bytes": torch.cuda.max_memory_allocated(), "bytes": os.path.getsize(out),
               "fov": a.fov, "seed": a.seed, "resolution": a.resolution}
        print("REPORT", json.dumps(rec), flush=True)
        report.append(rec)
    with open(os.path.join(a.out_dir, "report.json"), "w") as f:
        json.dump(report, f, indent=2)


if __name__ == "__main__":
    main()
