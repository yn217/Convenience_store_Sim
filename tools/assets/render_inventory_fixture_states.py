"""Render Issue #91 inventory-state fixtures from the shared Blender blueprints.

Example (Blender 2.91):
  blender -b --python tools/assets/render_inventory_fixture_states.py -- \
    --fixture fridge_drink --out build/fridge_drink_blender_v1

The script writes un-cropped RGBA layers and a calibration chart. It does not
change runtime files or game code.
"""
import argparse
import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "../.."))
sys.path.insert(0, HERE)
import blueprints
import iso2x
import render_fixtures as rf

STATES = ("FULL", "HALF", "EMPTY")
LAYERS = ("body", "products", "glass_front", "shadow")
PACKAGE_PALETTES = (
    ((0.04, 0.28, 0.19), (0.83, 0.77, 0.54), (0.55, 0.78, 0.51)),  # fictional tea
    ((0.94, 0.58, 0.08), (0.96, 0.84, 0.34), (0.84, 0.24, 0.08)),  # citrus soda
    ((0.24, 0.12, 0.08), (0.84, 0.58, 0.25), (0.12, 0.08, 0.06)),  # canned-style coffee bottle
)
_custom_materials = {}
_image_materials = {}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--fixture", default="fridge_drink", choices=("fridge_drink",))
    parser.add_argument("--out", required=True)
    return parser.parse_args(argv)


def material(name, color, roughness=0.35, metallic=0.0, alpha=1.0):
    key = (name, tuple(color), roughness, metallic, alpha)
    if key in _custom_materials:
        return _custom_materials[key]
    mat = bpy.data.materials.new("issue91_" + name)
    mat.diffuse_color = tuple(color) + (alpha,)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = tuple(color) + (alpha,)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
        mat.shadow_method = "NONE"
    _custom_materials[key] = mat
    return mat


def lathe(name, x, y, z, profile, mat_slots, ring_material_indices):
    """Create an axial bottle mesh from world-space profile (z-offset, radius)."""
    sides = 24
    verts = []
    faces = []
    for dz, radius in profile:
        for i in range(sides):
            theta = (2.0 * math.pi * i) / sides
            verts.append((x + radius * math.cos(theta), -(y + radius * math.sin(theta)), z + dz))
    for row in range(len(profile) - 1):
        for i in range(sides):
            a = row * sides + i
            b = row * sides + (i + 1) % sides
            c = (row + 1) * sides + (i + 1) % sides
            d = (row + 1) * sides + i
            faces.append((a, b, c, d))
    faces.append(tuple(range(sides - 1, -1, -1)))
    faces.append(tuple((len(profile) - 1) * sides + i for i in range(sides)))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.clear()
    for mat in mat_slots:
        mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    # Each profile interval has a material; the two caps use the end materials.
    interval_count = len(profile) - 1
    for poly in mesh.polygons:
        if len(poly.vertices) == 4:
            poly.material_index = ring_material_indices[min(poly.index // sides, interval_count - 1)]
        else:
            poly.material_index = len(mat_slots) - 1
    return obj


def label_texture_material(variant):
    if variant in _image_materials:
        return _image_materials[variant]
    names = ("green_tea", "citrus_soda", "unsweetened_coffee")
    image_path = os.path.join(ROOT, "assets/source/textures/packages/candidates/issue91_beverage_label_art_v01", names[variant], "label_art_v01.png")
    image = bpy.data.images.load(image_path, check_existing=True)
    image.pack()
    mat = bpy.data.materials.new("issue91_label_texture_" + names[variant])
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    texture.interpolation = "Linear"
    bsdf = nodes.get("Principled BSDF")
    mat.node_tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.52
    _image_materials[variant] = mat
    return mat


def add_uv_label_band(name, x, y, base_z, variant):
    """Wrap a generated flat package-art texture around the real bottle-sized label band."""
    sides = 48
    z0, z1, radius = 0.074, 0.141, 0.0347
    verts, faces = [], []
    for z in (z0, z1):
        for i in range(sides):
            theta = 2.0 * math.pi * i / sides
            verts.append((x + radius * math.cos(theta), -(y + radius * math.sin(theta)), base_z + z))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(label_texture_material(variant))
    uv_layer = mesh.uv_layers.new(name="PackageArtUV")
    for poly in mesh.polygons:
        i = poly.index
        u0, u1 = i / sides, (i + 1) / sides
        for loop_index, uv in zip(poly.loop_indices, ((u0, 0.0), (u1, 0.0), (u1, 1.0), (u0, 1.0))):
            uv_layer.data[loop_index].uv = uv
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_bottle(name, x, y, base_z, variant):
    label, accent, cap = PACKAGE_PALETTES[variant % len(PACKAGE_PALETTES)]
    plastic = material("pet_%d" % variant, (0.66, 0.84, 0.78) if variant == 0 else (0.75, 0.88, 0.92), 0.16, 0.0)
    label_mat = material("label_%d" % variant, label, 0.42)
    accent_mat = material("label_art_%d" % variant, accent, 0.48)
    cap_mat = material("cap_%d" % variant, cap, 0.3)
    # Overall height 0.225m; maximum diameter 0.068m per the shared product blueprint.
    profile = [
        (0.000, 0.029), (0.010, 0.034), (0.105, 0.034), (0.147, 0.032),
        (0.174, 0.024), (0.184, 0.016), (0.204, 0.015), (0.205, 0.015),
        (0.207, 0.018), (0.223, 0.018), (0.225, 0.016),
    ]
    # Label occupies a broad middle band; an accent stripe makes category colors legible at game zoom.
    intervals = [0, 0, 1, 0, 0, 0, 0, 3, 3, 3]
    obj = lathe(name, x, y, base_z, profile, [plastic, label_mat, accent_mat, cap_mat], intervals)
    # The generated art is UV-wrapped on a physical 67mm-wide label band.
    textured_label = add_uv_label_band(name + "_package_art", x, y, base_z, variant)
    lathe(name + "_label_top", x, y, base_z, [(0.074, 0.0346), (0.081, 0.0346)], [accent_mat], [0])
    lathe(name + "_label_bottom", x, y, base_z, [(0.141, 0.0326), (0.147, 0.0326)], [accent_mat], [0])
    return [obj, textured_label, bpy.data.objects[name + "_label_top"], bpy.data.objects[name + "_label_bottom"]]


def place_products(definition, rotation, state):
    blueprint = blueprints.build(definition)
    rotated = blueprints.rotated(blueprint, definition, rotation)
    rows = sorted(rotated["slots"].items())
    objects = []
    for row_index, (_slot_id, anchors) in enumerate(rows):
        if state == "FULL":
            selected = anchors
        elif state == "HALF":
            selected = [anchors[i] for i in (0, 2, 5, 7)]
        else:
            selected = []
        for i, (_item_id, (x, y, z)) in enumerate(selected):
            variant = (row_index + i) % len(PACKAGE_PALETTES)
            objects.extend(add_bottle("drink_%s_r%d_row%d_%d" % (state.lower(), rotation, row_index, i), x, y, z, variant))
    return objects


def main():
    args = parse_args()
    output = os.path.abspath(args.out)
    raw = os.path.join(output, "raw")
    os.makedirs(raw, exist_ok=True)
    catalog_path = os.path.join(ROOT, "data/fixtures/mvp_v1.json")
    with open(catalog_path, encoding="utf-8") as source:
        definition = next(item for item in json.load(source) if item["type_id"] == args.fixture)
    rf.setup_scene()
    calibration = os.path.join(raw, "calibration.png")
    calibration_info = rf.render_calibration(raw)
    info = {
        "issue": 91,
        "fixture_type_id": args.fixture,
        "visual_id": definition["visual_id"] + "_inventory_v2",
        "blender_version": bpy.app.version_string,
        "engine": "BLENDER_EEVEE",
        "projection_id": iso2x.PROJECTION_ID,
        "azimuth_deg": iso2x.AZIMUTH_DEG,
        "elevation_deg": iso2x.ELEVATION_DEG,
        "canvas_px": [rf.CANVAS, rf.CANVAS],
        "origin_px": [rf.CANVAS / 2.0, rf.CANVAS / 2.0],
        "calibration": calibration_info,
        "footprint": definition["footprint"],
        "dimensions_m": definition["dimensions_m"],
        "states": list(STATES),
        "rotations": {},
        "layer_order": ["shadow", "body", "products", "glass_front"],
    }
    for state in STATES:
        info["rotations"][state] = {}
        for rotation in range(4):
            rf.clear_models()
            rotated = blueprints.rotated(blueprints.build(definition), definition, rotation)
            objects = {layer: [] for layer in LAYERS}
            for index, box in enumerate(rotated["boxes"]):
                objects[box.layer].append(rf.add_box("fridge_r%d_%s_%d" % (rotation, box.layer, index), box.x0, box.y0, box.z0, box.x1, box.y1, box.z1, box.material))
            sx0, sy0, sx1, sy1 = rotated["shadow"]
            objects["shadow"].append(rf.add_box("fridge_r%d_shadow" % rotation, sx0, sy0, 0.0, sx1, sy1, 0.002, "shadow"))
            objects["products"] = place_products(definition, rotation, state)
            everything = [obj for layer in LAYERS for obj in objects[layer]]
            for layer in LAYERS:
                filename = "fridge_drink_%s_r%d_%s.png" % (state.lower(), rotation, layer)
                rf.render_to(os.path.join(raw, filename), [(obj, obj in objects[layer]) for obj in everything])
            # Authoritative candidate composite: Blender's depth test resolves opaque cabinet/product occlusion.
            rf.render_to(os.path.join(raw, "fridge_drink_%s_r%d_composite.png" % (state.lower(), rotation)), [(obj, True) for obj in everything])
            lo, hi = rf.mesh_bbox_game(objects["body"] + objects["glass_front"])
            product_bbox = rf.mesh_bbox_game(objects["products"]) if objects["products"] else None
            info["rotations"][state][str(rotation)] = {
                "mesh_bbox": {"min": lo, "max": hi},
                "products_bbox": ({"min": product_bbox[0], "max": product_bbox[1]} if product_bbox else None),
                "product_count": 24 if state == "FULL" else 12 if state == "HALF" else 0,
            }
            print("rendered", state, "r", rotation)
    with open(os.path.join(output, "render_info.json"), "w", encoding="utf-8", newline="\n") as target:
        json.dump(info, target, ensure_ascii=False, indent=2)
        target.write("\n")
    print("ISSUE91_BLENDER_RENDER_DONE", calibration)


if __name__ == "__main__":
    main()
