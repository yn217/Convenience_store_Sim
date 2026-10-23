"""Render fixture bodies with 3D slot markers for visual slot/mesh diagnosis.

Run through Blender. This is a diagnostic output and never modifies committed assets.
"""
import argparse
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blueprints  # noqa: E402
import render_fixtures  # noqa: E402


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--catalog", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--type", default="shelf_general")
    return p.parse_args(argv)


def main():
    args = parse_args()
    args.out = os.path.abspath(args.out)
    catalog = {d["type_id"]: d for d in json.loads(open(os.path.abspath(args.catalog), encoding="utf-8").read())}
    d = catalog[args.type]
    bp = blueprints.build(d)
    render_fixtures.setup_scene()
    os.makedirs(args.out, exist_ok=True)
    for rotation in range(4):
        render_fixtures.clear_models()
        rot = blueprints.rotated(bp, d, rotation)
        objects = []
        for i, box in enumerate(rot["boxes"]):
            objects.append(render_fixtures.add_box(f"body_{rotation}_{i}", box.x0, box.y0, box.z0, box.x1, box.y1, box.z1, box.material))
        for row_index, items in enumerate(rot["slots"].values()):
            for item_index, (_item_id, point) in enumerate(items):
                size = 0.055
                mat = "marker_x" if row_index % 2 == 0 else "marker_y"
                objects.append(render_fixtures.add_box(f"slot_{rotation}_{row_index}_{item_index}", point[0] - size, point[1] - size, point[2], point[0] + size, point[1] + size, point[2] + size * 2.0, mat))
        render_fixtures.render_to(os.path.join(args.out, f"{args.type}_r{rotation}_slots.png"), [(obj, True) for obj in objects])
    print(f"wrote slot diagnostics to {args.out}")


if __name__ == "__main__":
    main()
