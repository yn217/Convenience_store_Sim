"""Crop render_fixture.py output into game fixture layers + manifest (iso2x_v1, 1x1 footprint).

    python -I crop_fixture.py <render_dir> <type_id> <visual_id> <out_dir> W D H

Writes <type>_<r>_body.png and <type>_<r>_shadow.png (same canvas per rotation, >= 8 px padding) and
<visual_id>.visual.json. The anchor is the world origin = the centre of the fixture's tile on the floor.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PAD = 10
SHADOW_GROW_M = 0.06      # shadow reaches this far past the footprint (contract allows <= 0.15 m)
SHADOW_ALPHA = 70
HALF_W, HALF_H = 128.0, 64.0


def iso(x, y):
    return HALF_W * (x - y), HALF_H * (x + y)


def main():
    src, type_id, visual_id, out_dir = sys.argv[1:5]
    w, d, h = (float(v) for v in sys.argv[5:8])
    info = json.load(open(os.path.join(src, "%s_render_info.json" % type_id)))
    ox, oy = info["origin_px"]
    os.makedirs(out_dir, exist_ok=True)
    rotations = {}
    for r in range(4):
        body = Image.open(os.path.join(src, "%s_%d_body_full.png" % (type_id, r))).convert("RGBA")
        # shadow: the footprint diamond grown a little, blurred, on its own layer
        g = 0.5 + SHADOW_GROW_M
        sh = Image.new("L", body.size, 0)
        pts = [(ox + iso(x, y)[0], oy + iso(x, y)[1]) for x, y in ((-g, -g), (g, -g), (g, g), (-g, g))]
        ImageDraw.Draw(sh).polygon(pts, fill=SHADOW_ALPHA)
        sh = sh.filter(ImageFilter.GaussianBlur(6))
        shadow = Image.new("RGBA", body.size, (0, 0, 0, 0))
        shadow.putalpha(sh)
        a = np.maximum(np.array(body)[..., 3], np.array(sh))
        ys, xs = np.nonzero(a > 0)
        x0, y0 = int(max(0, xs.min() - PAD)), int(max(0, ys.min() - PAD))
        x1, y1 = int(min(body.width, xs.max() + 1 + PAD)), int(min(body.height, ys.max() + 1 + PAD))
        box = (x0, y0, x1, y1)
        names = {"body": "%s_%d_body.png" % (type_id, r), "shadow": "%s_%d_shadow.png" % (type_id, r)}
        body.crop(box).save(os.path.join(out_dir, names["body"]))
        shadow.crop(box).save(os.path.join(out_dir, names["shadow"]))
        ax, ay = round(ox - x0, 2), round(oy - y0, 2)
        poly = [[round(ax + iso(cx, cy)[0], 2), round(ay + iso(cx, cy)[1], 2)]
                for cx, cy in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5))]
        rotations[str(r)] = {
            "canvas_px": [x1 - x0, y1 - y0],
            "anchor_px": [ax, ay],
            "layers": {"body": names["body"], "shadow": names["shadow"]},
            "slot_anchors_px": {},
            "selection_polygon_px": poly,
            "sorting_anchor_px": [ax, ay],
        }
    manifest = {
        "manifest_version": 1,
        "visual_id": visual_id,
        "fixture_type_id": type_id,
        "projection_id": "iso2x_v1",
        "world_units_per_tile": 1,
        "source_px_per_tile_diamond": [256, 128],
        "footprint": {"w": 1, "h": 1},
        "dimensions_m": {"width": w, "depth": d, "height": h},
        "rotations": rotations,
    }
    with open(os.path.join(out_dir, "%s.visual.json" % visual_id), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(json.dumps({r: v["canvas_px"] for r, v in rotations.items()}))


if __name__ == "__main__":
    main()
