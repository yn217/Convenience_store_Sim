"""Blender renderer for customer sprites (Issue #23). Run it through Blender:

    blender -b --python tools/assets/render_customers.py -- --out build/asset_raw_customers

Same camera preset `iso2x_v1`, lights and colour management as the fixtures (it reuses
render_fixtures.setup_scene), a smaller canvas. One body render per variant x facing x anim x frame,
plus one blob shadow per variant. Calibration markers are rendered first in every batch.
"""
import argparse
import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import figures  # noqa: E402
import iso2x  # noqa: E402
import render_fixtures as rf  # noqa: E402

CANVAS = 768


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--variants", default=",".join(sorted(figures.VARIANTS)))
    args = p.parse_args(argv)
    out = os.path.abspath(args.out)   # Blender resolves relative render paths against the drive root
    raw = os.path.join(out, "raw")
    os.makedirs(raw, exist_ok=True)
    rf.CANVAS = CANVAS
    rf.PALETTE["shoe"] = {"color": figures.SHOE, "metallic": 0.0, "roughness": 0.6}
    for vid, spec in figures.VARIANTS.items():
        for part in ("shirt", "pants", "hair", "skin", "bag"):
            if spec.get(part) is not None:
                rf.PALETTE[figures.material_id(vid, part)] = {"color": spec[part], "metallic": 0.0, "roughness": 0.7}
    rf.setup_scene()
    info = {
        "blender_version": bpy.app.version_string,
        "engine": "BLENDER_EEVEE",
        "samples": rf.SAMPLES,
        "projection_id": iso2x.PROJECTION_ID,
        "canvas_px": [CANVAS, CANVAS],
        "origin_px": [CANVAS / 2.0, CANVAS / 2.0],
        "px_per_m_ortho": iso2x.PX_PER_M_ORTHO,
        "view_transform": "Standard",
        "look": "None",
        "calibration": rf.render_calibration(raw),
        "variants": {},
    }
    for vid in [v for v in args.variants.split(",") if v]:
        os.makedirs(os.path.join(raw, vid), exist_ok=True)
        info["variants"][vid] = {"height_m": figures.VARIANTS[vid]["height"]}
        rf.clear_models()
        x0, y0, z0, x1, y1, z1, m = figures.shadow_box()
        sh = rf.add_box("%s_shadow" % vid, x0, y0, z0, x1, y1, z1, m)
        rf.render_to(os.path.join(raw, vid, "shadow.png"), [(sh, True)])
        for facing in range(4):
            for anim, count in figures.ANIMS.items():
                for frame in range(count):
                    rf.clear_models()
                    for i, (a0, b0, c0, a1, b1, c1, mat) in enumerate(figures.facing_boxes(vid, anim, frame, facing)):
                        rf.add_box("%s_%d_%s_%d_%d" % (vid, facing, anim, frame, i), a0, b0, c0, a1, b1, c1, mat)
                    objs = [o for o in bpy.data.objects if o.type == "MESH"]
                    rf.render_to(os.path.join(raw, vid, "d%d_%s_%d.png" % (facing, anim, frame)), [(o, True) for o in objs])
        print("rendered", vid)
    with open(os.path.join(out, "render_info.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    print("RENDER_DONE")


main()
