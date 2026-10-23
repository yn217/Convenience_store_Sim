"""Render a shelf fixture's FULL/HALF/EMPTY candidates with the shared iso2x_v1 Blender scene.

Run from repository root with Blender 2.91:
  blender -b --python tools/assets/render_shelf_inventory_states.py -- --fixture shelf_general --out build/shelf_general_states
The script imports the existing camera, calibration and shelf blueprint; it creates no runtime files.
"""
import argparse
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
sys.path.insert(0, HERE)
import blueprints
import render_fixtures as rf

STATES = ("FULL", "HALF", "EMPTY")
COLORS = {
    "snack": [(0.76, 0.20, 0.11), (0.93, 0.60, 0.09), (0.24, 0.47, 0.25)],
    "instant_noodle": [(0.86, 0.32, 0.08), (0.82, 0.69, 0.18), (0.25, 0.41, 0.59)],
    "bread": [(0.70, 0.43, 0.19), (0.86, 0.68, 0.34), (0.55, 0.25, 0.16)],
}


def args_parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--fixture", default="shelf_general", choices=("shelf_general", "shelf_noodle"))
    p.add_argument("--out", required=True)
    return p.parse_args(argv)


def package_material(name, color, accent):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color + (1.0,)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color + (1.0,)
    bsdf.inputs["Roughness"].default_value = 0.38
    return mat


def add_carton(name, x, y, z, category, index):
    # Reusable low-poly package prop; dimensions are in metres and are never scaled per view.
    w = (0.105, 0.112, 0.125)[index % 3]
    d = (0.105, 0.115, 0.105)[index % 3]
    h = (0.205, 0.145, 0.175)[index % 3]
    mat = package_material("pkg_%s_%d" % (category, index), COLORS[category][index % 3], (1, 1, 1))
    # render_fixtures.add_box already converts game Y to Blender Y; keep inputs in game space.
    obj = rf.add_box(name, x-w/2, y-d/2, z, x+w/2, y+d/2, z+h, "product_surface")
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def place_products(d, rotation, state):
    bp = blueprints.build(d)
    rotated = blueprints.rotated(bp, d, rotation)
    rows = sorted(rotated["slots"].items())
    categories = ("instant_noodle",) if d["type_id"] == "shelf_noodle" else ("snack", "instant_noodle", "bread")
    objs = []
    for row_index, (_slot, anchors) in enumerate(rows):
        if not anchors:
            continue
        if state == "FULL":
            selected = anchors
        elif state == "HALF":
            selected = [anchors[i] for i in (0, 2, 5, 7)]
        else:
            selected = []
        # Use 3D blueprint anchors so products stay on the shelves in each true fixture rotation.
        for i, (_item_id, (x, y, z)) in enumerate(selected):
            cat = categories[(row_index+i) % len(categories)]
            objs.append(add_carton("product_%s_r%d_%d_%d" % (state.lower(), rotation, row_index, i), x, y, z, cat, i+row_index))
    return objs


def main():
    a = args_parse()
    out = os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    raw = os.path.join(out, "raw")
    os.makedirs(raw, exist_ok=True)
    rf.setup_scene()
    catalog_path = os.path.join(ROOT, "data/fixtures/mvp_v1.json")
    with open(catalog_path, encoding="utf-8") as f:
        d = next(x for x in json.load(f) if x["type_id"] == a.fixture)
    calibration_dir = os.path.join(raw, "raw")
    os.makedirs(calibration_dir, exist_ok=True)
    cal_info = rf.render_calibration(calibration_dir)
    info = {"blender_version": bpy.app.version_string, "engine": "BLENDER_EEVEE", "samples": rf.SAMPLES,
            "projection_id": "iso2x_v1", "canvas_px": [rf.CANVAS, rf.CANVAS],
            "origin_px": [rf.CANVAS/2, rf.CANVAS/2], "calibration": cal_info,
            "fixture_type_id": a.fixture, "visual_id": d["visual_id"], "dimensions_m": d["dimensions_m"],
            "footprint": d["footprint"], "states": list(STATES), "rotations": {}}
    for state in STATES:
        info["rotations"][state] = {}
        for rotation in range(4):
            rf.clear_models()
            bp = blueprints.rotated(blueprints.build(d), d, rotation)
            body, shadow, products = [], [], []
            for i, box in enumerate(bp["boxes"]):
                body.append(rf.add_box("shelf_r%d_%d" % (rotation, i), box.x0, box.y0, box.z0,
                                       box.x1, box.y1, box.z1, box.material))
            sx0, sy0, sx1, sy1 = bp["shadow"]
            shadow.append(rf.add_box("shadow_r%d" % rotation, sx0, -sy0, 0, sx1, -sy1, .002, "shadow"))
            products = place_products(d, rotation, state)
            every = body + shadow + products
            layers = {"body": body, "products": products, "shadow": shadow}
            for lname, objs in layers.items():
                path = os.path.join(calibration_dir, "%s_%s_r%d_%s.png" % (a.fixture, state.lower(), rotation, lname))
                rf.render_to(path, [(obj, obj in objs) for obj in every])
            lo, hi = rf.mesh_bbox_game(body)
            info["rotations"][state][str(rotation)] = {"mesh_bbox": {"min": lo, "max": hi}}
            print("rendered", state, "r", rotation)
    info["calibration"]["file"] = "calibration.png"
    with open(os.path.join(out, "render_info.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=2)
    print("SHELF_STATES_RENDER_DONE")


if __name__ == "__main__":
    main()
