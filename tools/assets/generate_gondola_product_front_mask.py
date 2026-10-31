#!/usr/bin/env python3
"""Derive a front-facing merchandise mask from an iso2x fixture guide.

This produces a diagnostic conditioning mask only. It never edits the guide,
source sprite, fixture art, or runtime assets.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("guide", type=Path, help="guide.json generated from the fixture catalog")
    ap.add_argument("output_png", type=Path)
    ap.add_argument("output_json", type=Path)
    ap.add_argument("--slot-count", type=int, default=9)
    ap.add_argument("--side-margin-m", type=float, default=0.06)
    ap.add_argument("--product-height-m", type=float, default=0.20)
    ap.add_argument("--front-inset-m", type=float, default=0.07)
    args = ap.parse_args()

    guide_path = args.guide.resolve()
    guide = json.loads(guide_path.read_text(encoding="utf-8"))
    w, h = map(int, guide["canvas_px"])
    anchor_u, anchor_v = map(float, guide["anchor_px"])
    vx, vy, vz = guide["source_axis_vectors"]

    def project(point: tuple[float, float, float]) -> tuple[float, float]:
        x, y, z = point
        return (
            anchor_u + vx[0] * x + vy[0] * y + vz[0] * z,
            anchor_v + vx[1] * x + vy[1] * y + vz[1] * z,
        )

    guide_mask_path = guide_path.parent / "guide_mask.png"
    base = Image.open(guide_mask_path).convert("RGBA")
    if base.size != (w, h):
        raise ValueError(f"guide mask size {base.size} does not match guide canvas {(w, h)}")
    rgb = Image.new("RGB", (w, h), (0, 0, 0))
    src = base.convert("RGB")
    pixels = src.load()
    out = rgb.load()
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            if r > 120 and g < 40 and b < 40:
                out[x, y] = (220, 0, 0)  # fixed structure

    boards = sorted(
        (p for p in guide["parts"] if p["name"].startswith("sales_board_")),
        key=lambda p: int(p["name"].rsplit("_", 1)[1]),
    )
    expected = int(guide["sales_board_count"])
    if len(boards) != expected:
        raise ValueError(f"guide declares {expected} sales boards but contains {len(boards)}")
    if guide["sales_face"] != ["E"]:
        raise ValueError(f"this pilot handles E-facing shelves only, got {guide['sales_face']}")

    draw = ImageDraw.Draw(rgb)
    rows = []
    span_total = 0.0
    green = (0, 180, 0)
    for board in boards:
        _, y_min, _, x_max, y_max, z_top = map(float, board["bounds_m"])
        y0, y1 = y_min + args.side_margin_m, y_max - args.side_margin_m
        span = y1 - y0
        gap = 0.012
        slot_w = (span - gap * (args.slot_count - 1)) / args.slot_count
        x_front = x_max - args.front_inset_m
        height = min(args.product_height_m, float(guide["dimensions_m"]["height"]) - z_top - 0.025)
        if height <= 0:
            raise ValueError(f"no vertical room above {board['name']}")
        slots = []
        for i in range(args.slot_count):
            sy0 = y0 + i * (slot_w + gap)
            sy1 = sy0 + slot_w
            world = [
                [x_front, sy0, z_top],
                [x_front, sy1, z_top],
                [x_front, sy1, z_top + height],
                [x_front, sy0, z_top + height],
            ]
            source = [project(tuple(v)) for v in world]
            draw.polygon([(round(x), round(y)) for x, y in source], fill=green)
            slots.append({"world_front_quad": world, "source_quad_px": [[round(x, 4), round(y, 4)] for x, y in source]})
        rows.append({"board": board["name"], "board_top_z_m": z_top, "product_front_x_m": x_front, "product_height_m": height, "slots": slots})
        span_total += span

    args.output_png.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    rgb.save(args.output_png)
    report = {
        "schema_version": 1,
        "asset_id": guide["asset_id"],
        "purpose": "ImageGen conditioning diagnostic; not runtime art or fixture geometry",
        "source_guide": str(guide_path),
        "source_guide_sha256": sha256(guide_path),
        "source_mask_sha256": sha256(guide_mask_path),
        "source_projection_sha256": guide["projection_sha256"],
        "canvas_px": [w, h],
        "anchor_px": [anchor_u, anchor_v],
        "world_axis_source_vectors": [vx, vy, vz],
        "customer_access_face": "E/+X",
        "rules": {"slot_count_per_row": args.slot_count, "side_margin_m": args.side_margin_m, "slot_gap_m": 0.012, "front_inset_m": args.front_inset_m, "product_height_m": args.product_height_m},
        "rows": rows,
        "output_png_sha256": sha256(args.output_png),
        "colors": {"fixed_structure": [220, 0, 0], "product_front_region": list(green), "forbidden_background": [0, 0, 0]},
        "runtime_approved": False,
        "limitations": ["Front-face regions are projected from the fixture guide, but product art is still generated and requires boundary/occlusion QA.", "This mask does not prove the ImageGen output follows the guide."],
    }
    args.output_json.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"rows": len(rows), "slots": sum(len(r["slots"]) for r in rows), "canvas": [w, h], "png_sha256": report["output_png_sha256"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
