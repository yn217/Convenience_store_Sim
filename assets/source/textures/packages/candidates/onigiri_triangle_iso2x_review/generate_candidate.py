"""Deterministic Pillow generator for the onigiri_triangle review candidate.

This is intentionally review-only: it never writes into runtime/generated asset roots.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
W, H = 128, 96
RGBA = ("RGBA", (W, H))


def project(x: float, y: float, z: float, r: int) -> tuple[float, float]:
    # iso2x_v1 source projection, with a deterministic 90-degree world rotation.
    ca, sa = [(1, 0), (0, 1), (-1, 0), (0, -1)][r]
    xr, yr = ca * x - sa * y, sa * x + ca * y
    return (64 + 128 * (xr - yr), 48 + 64 * (xr + yr) - 156.76734354 * z)


def make_direction(r: int) -> Image.Image:
    im = Image.new(*RGBA, (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    # A small grounded shadow, body, and label; all dimensions are derived from
    # the contract dimensions rather than a later image stretch.
    pts = [project(-0.0525, -0.0225, 0.002, r), project(0.0525, -0.0225, 0.002, r),
           project(0.0525, 0.0225, 0.002, r), project(-0.0525, 0.0225, 0.002, r)]
    shadow = [(x + 2, y + 3) for x, y in pts]
    d.polygon(shadow, fill=(20, 24, 30, 70))
    body = [project(-0.0525, -0.0225, 0.005, r), project(0.0525, -0.0225, 0.005, r),
            project(0.0525, 0.0225, 0.005, r), project(-0.0525, 0.0225, 0.005, r)]
    d.polygon(body, fill=(246, 244, 236, 255), outline=(196, 190, 176, 255))
    top = [project(-0.0525, -0.0225, 0.095, r), project(0.0525, -0.0225, 0.095, r),
           project(0.0525, 0.0225, 0.095, r), project(-0.0525, 0.0225, 0.095, r)]
    d.polygon(top, fill=(255, 251, 241, 255), outline=(203, 193, 175, 255))
    # Rice triangle silhouette and nori band as deterministic product art.
    cx, cy = project(0, 0, 0.10, r)
    tri = [(cx, cy - 7), (cx - 8, cy + 5), (cx + 8, cy + 5)]
    d.polygon(tri, fill=(235, 238, 231, 255), outline=(126, 137, 126, 255))
    d.line([(cx - 6, cy + 1), (cx + 6, cy + 1)], fill=(35, 56, 48, 255), width=3)
    d.line([(cx, cy - 5), (cx, cy + 5)], fill=(255, 255, 255, 180), width=1)
    return im


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    images = []
    for r in range(4):
        name = f"onigiri_triangle_r{r}.png"
        path = ROOT / name
        make_direction(r).save(path, format="PNG", optimize=False, compress_level=9)
        images.append({"rotation": r, "path": name, "sha256": sha256(path), "rgba": True})
    manifest = {
        "manifest_version": 1,
        "visual_id": "onigiri_triangle_iso2x_review",
        "shape_id": "onigiri_triangle",
        "projection_id": "iso2x_v1",
        "dimensions_m": {"width": 0.105, "depth": 0.045, "height": 0.095},
        "canvas_px": [W, H],
        "anchor_px": [64, 48],
        "slot_units": 1,
        "runtime_approved": False,
        "review_only": True,
        "directions": images,
        "provenance": {
            "generator": "generate_candidate.py",
            "renderer": "Pillow",
            "deterministic": True,
            "source_contracts": [
                "docs/implementation/06_ASSET_BLUEPRINTS_AND_VALIDATION.md",
                "docs/implementation/02_GRID_AND_ASSET_CONTRACT.md",
            ],
            "note": "Review-only candidate; Blender calibration and semantic validation are not claimed PASS.",
        },
    }
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "SHA256SUMS.txt").write_text("".join(f"{item['sha256']}  {item['path']}\n" for item in images), encoding="ascii")
    (ROOT / "provenance.json").write_text(json.dumps(manifest["provenance"], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "SHA256SUMS.txt").write_text("".join(f"{sha256(ROOT / item['path'])}  {item['path']}\n" for item in images), encoding="ascii")


if __name__ == "__main__":
    main()
