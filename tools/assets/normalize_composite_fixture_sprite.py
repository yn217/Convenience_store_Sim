"""Normalize one generated combined shelf+stock illustration to a fixture sprite contract.

The resulting PNG remains one flat 2D image. This only crops, optionally mirrors
the image to match the canonical slot-axis direction, scales it, and places it
on the existing transparent canvas. It never creates product meshes.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def normalize(source: Path, output: Path, canvas: tuple[int, int], target_box: tuple[int, int, int, int],
              anchor: tuple[float, float], flip_x: bool, stretch_to_box: bool = False,
              alpha_threshold: int = 8) -> dict:
    im = Image.open(source).convert("RGBA")
    alpha = im.getchannel("A").point(lambda value: 0 if value < alpha_threshold else value)
    im.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("source alpha is empty")
    im = im.crop(bbox)
    if flip_x:
        im = im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    left, top, right, bottom = target_box
    box_w, box_h = right - left, bottom - top
    scale = min(box_w / im.width, box_h / im.height)
    sx, sy = (box_w / im.width, box_h / im.height) if stretch_to_box else (scale, scale)
    size = (max(1, round(im.width * sx)), max(1, round(im.height * sy)))
    im = im.resize(size, Image.Resampling.LANCZOS)
    fitted_bbox = im.getchannel("A").getbbox()
    if fitted_bbox is None:
        raise ValueError("resized source alpha is empty")
    if stretch_to_box:
        # Match the visible alpha bounds rather than the resampling canvas. Edge
        # antialiasing can leave a few transparent pixels after Lanczos scaling.
        for _ in range(3):
            bw, bh = fitted_bbox[2] - fitted_bbox[0], fitted_bbox[3] - fitted_bbox[1]
            if bw <= 0 or bh <= 0:
                raise ValueError(f"invalid resized alpha bbox: {fitted_bbox}")
            fx, fy = box_w / bw, box_h / bh
            if abs(fx - 1.0) < 0.001 and abs(fy - 1.0) < 0.001:
                break
            size = (max(1, round(im.width * fx)), max(1, round(im.height * fy)))
            im = im.resize(size, Image.Resampling.LANCZOS)
            sx *= fx
            sy *= fy
            fitted_bbox = im.getchannel("A").getbbox()
        if fitted_bbox is None or (fitted_bbox[2] - fitted_bbox[0], fitted_bbox[3] - fitted_bbox[1]) != (box_w, box_h):
            raise ValueError(f"could not match visible alpha to contract box: {fitted_bbox} vs {(box_w, box_h)}")
    canvas_im = Image.new("RGBA", canvas, (0, 0, 0, 0))
    if stretch_to_box:
        x, y = left - fitted_bbox[0], top - fitted_bbox[1]
    else:
        x = round((left + right - size[0]) / 2)
        y = bottom - size[1]
    canvas_im.alpha_composite(im, (x, y))
    out_bbox = canvas_im.getchannel("A").getbbox()
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas_im.save(output, optimize=True)
    report = {
        "source": str(source), "output": str(output), "source_alpha_bbox": list(bbox),
        "source_content_px": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "source_alpha_threshold": alpha_threshold,
        "source_mirrored_horizontally": flip_x, "target_canvas_px": list(canvas),
        "fit_mode": "stretch_to_contract_alpha_box" if stretch_to_box else "uniform_contain",
        "fixture_contract": {"projection_id": "iso2x_v1", "footprint_tiles": [1, 2],
                             "anchor_px": list(anchor), "target_alpha_box_px": list(target_box)},
        "normalized_content_px": list(size), "scale_xy": [round(sx, 8), round(sy, 8)],
        "aspect_change_percent": round((sx / sy - 1.0) * 100.0, 4),
        "output_alpha_bbox_px": list(out_bbox) if out_bbox else None,
        "runtime_approved": False,
        "notes": ["single combined shelf and merchandise raster", "no separate product placements",
                  "candidate only; no runtime integration",
                  "stretch mode applies non-uniform 2D scaling to match fixture alpha bounds; inspect for distortion" if stretch_to_box else "uniform scale preserves source proportions"],
    }
    output.with_suffix(".visual.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--source", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--canvas", type=int, nargs=2, default=(442, 449))
    p.add_argument("--target-alpha-box", type=int, nargs=4, default=(38, 8, 403, 425))
    p.add_argument("--anchor", type=float, nargs=2, default=(285.0, 302.0))
    p.add_argument("--flip-x", action="store_true")
    p.add_argument("--stretch-to-box", action="store_true")
    p.add_argument("--alpha-threshold", type=int, default=8)
    a = p.parse_args()
    print(json.dumps(normalize(a.source, a.out, tuple(a.canvas), tuple(a.target_alpha_box),
                               tuple(a.anchor), a.flip_x, a.stretch_to_box, a.alpha_threshold), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
