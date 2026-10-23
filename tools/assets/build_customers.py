"""Crops customer renders into sprites and writes one manifest per variant (Issue #23).

    python tools/assets/build_customers.py --raw build/asset_raw_customers --out assets/generated/characters

All frames of a variant (4 facings x walk/idle/inspect) share ONE crop rectangle (union alpha bbox +
8 source px padding), so canvas_px and anchor_px are identical everywhere: switching facing or
frame can never move the feet. anchor_px is the world (0,0,0) projection (the render origin) minus
the crop's top-left. Nothing is scaled, stretched or mirrored.
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
import figures  # noqa: E402
import iso2x  # noqa: E402

PADDING = 8


def load_rgba(path):
    with Image.open(path) as img:
        return np.array(img.convert("RGBA"))


def opaque_bbox(arr):
    ys, xs = np.nonzero(arr[..., 3] > 0)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def build_variant(vid, info, raw_dir, out_dir):
    cw, ch = info["canvas_px"]
    ox, oy = info["origin_px"]
    shadow = load_rgba(os.path.join(raw_dir, vid, "shadow.png"))
    frames = {}
    boxes = [opaque_bbox(shadow)]
    for facing in range(4):
        for anim, count in figures.ANIMS.items():
            for k in range(count):
                arr = load_rgba(os.path.join(raw_dir, vid, "d%d_%s_%d.png" % (facing, anim, k)))
                frames[(facing, anim, k)] = arr
                boxes.append(opaque_bbox(arr))
    left = min(b[0] for b in boxes) - PADDING
    top = min(b[1] for b in boxes) - PADDING
    right = max(b[2] for b in boxes) + PADDING
    bottom = max(b[3] for b in boxes) + PADDING
    if left < 0 or top < 0 or right > cw or bottom > ch:
        raise SystemExit("%s: sprite plus padding does not fit the %dx%d render canvas" % (vid, cw, ch))
    dest = os.path.join(out_dir, vid)
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    Image.fromarray(shadow[top:bottom, left:right], "RGBA").save(os.path.join(dest, "shadow.png"), optimize=True)
    directions = {}
    for facing in range(4):
        directions[str(facing)] = {}
        for anim, count in figures.ANIMS.items():
            names = []
            for k in range(count):
                rel = "d%d_%s_f%d.png" % (facing, anim, k)
                Image.fromarray(frames[(facing, anim, k)][top:bottom, left:right], "RGBA").save(os.path.join(dest, rel), optimize=True)
                names.append(rel)
            directions[str(facing)][anim] = names
    manifest = {
        "manifest_version": 1,
        "visual_id": vid,
        "projection_id": iso2x.PROJECTION_ID,
        "world_units_per_tile": 1,
        "source_px_per_tile_diamond": list(iso2x.SOURCE_PX_PER_TILE_DIAMOND),
        "height_m": figures.VARIANTS[vid]["height"],
        "facing_names": list(figures.FACINGS),
        "canvas_px": [right - left, bottom - top],
        "anchor_px": [round(ox - left, 2), round(oy - top, 2)],
        "shadow": "shadow.png",
        "animations": {a: {"frames": n, "fps": round(figures.FPS[a], 4), "loop": figures.LOOP[a]} for a, n in figures.ANIMS.items()},
        "directions": directions,
    }
    path = os.path.join(dest, "%s.character.json" % vid)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return path


def file_hash(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()[:16]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    with open(os.path.join(args.raw, "render_info.json"), encoding="utf-8") as f:
        info = json.load(f)
    for vid in sorted(info["variants"]):
        print("built", build_variant(vid, info, os.path.join(args.raw, "raw"), args.out))
    here = os.path.dirname(os.path.abspath(__file__))
    provenance = {
        "projection_id": info["projection_id"],
        "blender_version": info["blender_version"],
        "engine": info["engine"],
        "samples": info["samples"],
        "view_transform": info["view_transform"],
        "render_canvas_px": info["canvas_px"],
        "padding_px": PADDING,
        "variants": sorted(info["variants"]),
        "origin_px": info["origin_px"],
        "generator_sha256_16": {n: file_hash(os.path.join(here, n)) for n in ("iso2x.py", "figures.py", "render_customers.py", "build_customers.py")},
        "calibration": {"file": "calibration/iso2x_v1_calibration.png", "markers": info["calibration"]["markers"]},
    }
    os.makedirs(os.path.join(args.out, "calibration"), exist_ok=True)
    shutil.copyfile(os.path.join(args.raw, "raw", info["calibration"]["file"]), os.path.join(args.out, "calibration", "iso2x_v1_calibration.png"))
    with open(os.path.join(args.out, "PROVENANCE.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(provenance, f, ensure_ascii=False, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main()
