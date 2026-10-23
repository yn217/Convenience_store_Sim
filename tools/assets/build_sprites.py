"""Crops the full-canvas Blender renders into sprites and writes the visual manifests (Issue #8).

    python tools/assets/build_sprites.py --catalog data/fixtures/mvp_v1.json \
        --raw build/asset_raw --out assets/generated/fixtures

Per direction all layers share ONE crop rectangle (union alpha bbox + 8 source px padding), so
canvas_px and anchor_px are identical for every layer. anchor_px is the world (0,0,0) projection
(the render origin) minus the crop's top-left; slot anchors and the selection polygon are
projected from 3D positions with the same math. Nothing is scaled or stretched.
Needs Pillow and numpy (pip install pillow numpy).
"""
import argparse
import hashlib
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blueprints  # noqa: E402
import iso2x  # noqa: E402

PADDING = 8


def load_rgba(path):
    with Image.open(path) as img:
        return np.array(img.convert("RGBA"))


def opaque_bbox(arr):
    ys, xs = np.nonzero(arr[..., 3] > 0)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def union(boxes):
    boxes = [b for b in boxes if b is not None]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))


def r2(v):
    return round(float(v), 2)


def build_type(d, info, raw_dir, out_dir):
    type_id = d["type_id"]
    w, h = d["footprint"]["w"], d["footprint"]["h"]
    canvas_w, canvas_h = info["canvas_px"]
    ox, oy = info["origin_px"]
    bp = blueprints.build(d)
    dest = os.path.join(out_dir, type_id)
    os.makedirs(dest, exist_ok=True)
    manifest = {
        "manifest_version": 1,
        "visual_id": d["visual_id"],
        "fixture_type_id": type_id,
        "projection_id": iso2x.PROJECTION_ID,
        "world_units_per_tile": 1,
        "source_px_per_tile_diamond": list(iso2x.SOURCE_PX_PER_TILE_DIAMOND),
        "footprint": {"w": w, "h": h},
        "dimensions_m": d["dimensions_m"],
        "rotations": {},
    }
    for r in range(4):
        rinfo = info["types"][type_id]["rotations"][str(r)]
        layers = {name: load_rgba(os.path.join(raw_dir, type_id, "r%d_%s.png" % (r, name))) for name in rinfo["layers"]}
        x0, y0, x1, y1 = union([opaque_bbox(a) for a in layers.values()])
        left, top, right, bottom = x0 - PADDING, y0 - PADDING, x1 + PADDING, y1 + PADDING
        if left < 0 or top < 0 or right > canvas_w or bottom > canvas_h:
            raise SystemExit("%s r%d: sprite plus padding does not fit the %dx%d render canvas" % (type_id, r, canvas_w, canvas_h))
        files = {}
        for name, arr in layers.items():
            fname = "%s_%d_%s.png" % (type_id, r, name)
            Image.fromarray(arr[top:bottom, left:right], "RGBA").save(os.path.join(dest, fname), optimize=True)
            files[name] = fname
        anchor = (ox - left, oy - top)
        rot = blueprints.rotated(bp, d, r)
        slots = {}
        for items in rot["slots"].values():
            for item_id, (px, py, pz) in items:
                u, v = iso2x.project(px, py, pz)
                slots[item_id] = [r2(anchor[0] + u), r2(anchor[1] + v)]
        fx0, fy0, fx1, fy1 = iso2x.rotated_footprint_rect(w, h, r)
        polygon = []
        for cx, cy in ((fx0, fy0), (fx1, fy0), (fx1, fy1), (fx0, fy1)):
            u, v = iso2x.project(cx, cy, 0.0)
            polygon.append([r2(anchor[0] + u), r2(anchor[1] + v)])
        manifest["rotations"][str(r)] = {
            "canvas_px": [right - left, bottom - top],
            "anchor_px": [r2(anchor[0]), r2(anchor[1])],
            "layers": files,
            "slot_anchors_px": slots,
            "selection_polygon_px": polygon,
            "sorting_anchor_px": [r2(anchor[0]), r2(anchor[1])],
        }
    path = os.path.join(dest, "%s.visual.json" % d["visual_id"])
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return path


def file_hash(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()[:16]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--catalog", required=True)
    p.add_argument("--raw", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    with open(os.path.join(args.raw, "render_info.json"), encoding="utf-8") as f:
        info = json.load(f)
    with open(args.catalog, encoding="utf-8") as f:
        catalog = {d["type_id"]: d for d in json.load(f)}
    here = os.path.dirname(os.path.abspath(__file__))
    built = []
    for type_id in sorted(info["types"]):
        built.append(build_type(catalog[type_id], info, os.path.join(args.raw, "raw"), args.out))
        print("built", built[-1])
    provenance = {
        "projection_id": info["projection_id"],
        "blender_version": info["blender_version"],
        "engine": info["engine"],
        "samples": info["samples"],
        "view_transform": info["view_transform"],
        "render_canvas_px": info["canvas_px"],
        "padding_px": PADDING,
        "types": sorted(info["types"]),
        "origin_px": info["origin_px"],
        "mesh_bbox": {t: {r: v["mesh_bbox"] for r, v in info["types"][t]["rotations"].items()} for t in sorted(info["types"])},
        "generator_sha256_16": {n: file_hash(os.path.join(here, n)) for n in ("iso2x.py", "blueprints.py", "render_fixtures.py", "build_sprites.py")},
        "calibration": {"file": "calibration/iso2x_v1_calibration.png", "markers": info["calibration"]["markers"]},
    }
    os.makedirs(os.path.join(args.out, "calibration"), exist_ok=True)
    shutil.copyfile(os.path.join(args.raw, "raw", info["calibration"]["file"]), os.path.join(args.out, "calibration", "iso2x_v1_calibration.png"))
    with open(os.path.join(args.out, "PROVENANCE.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(provenance, f, ensure_ascii=False, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main()
