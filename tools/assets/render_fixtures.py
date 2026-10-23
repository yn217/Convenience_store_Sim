"""Blender renderer for fixture sprites (Issue #8). Run it through Blender, not plain Python:

    blender -b --python tools/assets/render_fixtures.py -- --catalog data/fixtures/mvp_v1.json \
        --out build/asset_raw [--types shelf_general,warmer_oden,freezer_ice]

It writes full-canvas RGBA layer PNGs (no cropping yet) plus render_info.json. Cropping, anchors
and the manifest come from build_sprites.py, which uses the same iso2x math. Every asset uses the
same camera preset `iso2x_v1`, lights and materials; there is no per-asset scale or exposure.
Blender world (bx, by, bz) = (game x, -game y, game z): game y points south, Blender y north.
"""
import argparse
import json
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blueprints  # noqa: E402
import iso2x  # noqa: E402

CANVAS = 1600
SAMPLES = 64
CAMERA_DISTANCE = 30.0

PALETTE = {
    # Keep the white fixtures readable under the shared key/fill lights; the previous
    # near-white value clipped the top faces and erased shelf/side-panel separation.
    "frame_metal": {"color": (0.38, 0.41, 0.46), "metallic": 0.75, "roughness": 0.42},
    "shelf_white": {"color": (0.72, 0.75, 0.78), "metallic": 0.0, "roughness": 0.58},
    "dark_polymer": {"color": (0.08, 0.09, 0.10), "metallic": 0.0, "roughness": 0.60},
    "label_rail": {"color": (0.85, 0.75, 0.20), "metallic": 0.0, "roughness": 0.50},
    "product_surface": {"color": (0.50, 0.50, 0.50), "metallic": 0.0, "roughness": 0.50},
    "clear_glass": {"color": (0.70, 0.85, 0.95), "metallic": 0.0, "roughness": 0.05, "alpha": 0.22},
    "shadow": {"color": (0.0, 0.0, 0.0), "metallic": 0.0, "roughness": 1.0, "alpha": 0.32},
}
LED_COLOR = (0.85, 0.97, 1.0)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--catalog", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--types", default=",".join(blueprints.supported_types()))
    return p.parse_args(argv)


def b_co(x, y, z):
    """Game coordinates -> Blender coordinates."""
    return (x, -y, z)


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    r = sc.render
    r.engine = "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = SAMPLES
    sc.eevee.use_gtao = False
    sc.eevee.use_ssr = False
    sc.eevee.use_bloom = False
    sc.eevee.use_soft_shadows = True
    r.film_transparent = True
    r.resolution_x = r.resolution_y = CANVAS
    r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    r.image_settings.compression = 15
    r.dither_intensity = 0.0
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.view_settings.gamma = 1.0
    sc.display_settings.display_device = "sRGB"
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0

    world = bpy.data.worlds.new("iso2x_world")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.58, 0.62, 1.0)
    bg.inputs[1].default_value = 0.9
    sc.world = world

    for name, energy, rot in (("key", 3.0, (50.0, 0.0, -35.0)), ("fill", 1.0, (60.0, 0.0, 125.0))):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = tuple(math.radians(a) for a in rot)
        sc.collection.objects.link(obj)

    cam = bpy.data.cameras.new("iso2x_v1")
    cam.type = "ORTHO"
    cam.ortho_scale = CANVAS / iso2x.PX_PER_M_ORTHO
    cam.clip_start = 0.1
    cam.clip_end = 100.0
    cam.sensor_fit = "AUTO"
    cobj = bpy.data.objects.new("iso2x_v1", cam)
    el = math.radians(iso2x.ELEVATION_DEG)
    # The camera sits on the +x / -y (Blender) side so game +X projects to the right and down.
    cobj.location = (
        CAMERA_DISTANCE * math.cos(el) * math.sqrt(0.5),
        -CAMERA_DISTANCE * math.cos(el) * math.sqrt(0.5),
        CAMERA_DISTANCE * math.sin(el),
    )
    cobj.rotation_euler = (math.radians(90.0 - iso2x.ELEVATION_DEG), 0.0, math.radians(iso2x.AZIMUTH_DEG))
    sc.collection.objects.link(cobj)
    sc.camera = cobj
    return sc


_materials = {}


def material(mid):
    if mid in _materials:
        return _materials[mid]
    mat = bpy.data.materials.new(mid)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    if mid == "cool_white_led" or mid.startswith("marker_"):
        color = LED_COLOR if mid == "cool_white_led" else MARKERS[mid][1]
        for n in list(nodes):
            nodes.remove(n)
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs[0].default_value = color + (1.0,)
        emit.inputs[1].default_value = 1.0
        out = nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(emit.outputs[0], out.inputs[0])
    else:
        spec = PALETTE[mid]
        bsdf = nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = spec["color"] + (1.0,)
        bsdf.inputs["Metallic"].default_value = spec["metallic"]
        bsdf.inputs["Roughness"].default_value = spec["roughness"]
        if mid in ("clear_glass", "shadow"):
            bsdf.inputs["Alpha"].default_value = spec["alpha"]
            mat.blend_method = "BLEND"
            mat.shadow_method = "NONE"
            if mid == "shadow":
                bsdf.inputs["Specular"].default_value = 0.0
    _materials[mid] = mat
    return mat


def add_box(name, x0, y0, z0, x1, y1, z1, mat_id):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    cx, cy, cz = (x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0
    sx, sy, sz = x1 - x0, y1 - y0, z1 - z0
    for v in bm.verts:
        bx, by, bz = b_co(cx + v.co.x * sx, cy + v.co.y * sy, cz + v.co.z * sz)
        v.co = (bx, by, bz)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material(mat_id))
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def clear_models():
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            me = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            bpy.data.meshes.remove(me)


def render_to(path, visible):
    sc = bpy.context.scene
    for obj, show in visible:
        obj.hide_render = not show
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def mesh_bbox_game(objs):
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for obj in objs:
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            g = (w.x, -w.y, w.z)
            for i in range(3):
                lo[i] = min(lo[i], g[i])
                hi[i] = max(hi[i], g[i])
    return lo, hi


# Calibration markers: id -> (game position, pure colour). 4 cm cubes; their projected centroid
# is the projection of the centre because parallel projection keeps a cube symmetric.
MARKERS = {
    "marker_o": ((0.0, 0.0, 0.0), (1.0, 1.0, 1.0)),
    "marker_x": ((1.0, 0.0, 0.0), (1.0, 0.0, 0.0)),
    "marker_y": ((0.0, 1.0, 0.0), (0.0, 1.0, 0.0)),
    "marker_z": ((0.0, 0.0, 1.0), (0.0, 0.0, 1.0)),
}


def render_calibration(out_dir):
    clear_models()
    half = 0.02
    for mid, (p, _c) in MARKERS.items():
        add_box(mid, p[0] - half, p[1] - half, p[2] - half, p[0] + half, p[1] + half, p[2] + half, mid)
    path = os.path.join(out_dir, "calibration.png")
    render_to(path, [(o, True) for o in bpy.data.objects if o.type == "MESH"])
    return {"file": "calibration.png", "markers": {k: {"position": list(v[0]), "color": list(v[1])} for k, v in MARKERS.items()}}


def main():
    args = parse_args()
    args.out = os.path.abspath(args.out)   # Blender resolves relative render paths against the drive root
    args.catalog = os.path.abspath(args.catalog)
    with open(args.catalog, encoding="utf-8") as f:
        catalog = {d["type_id"]: d for d in json.load(f)}
    types = [t for t in args.types.split(",") if t]
    unknown = [t for t in types if t not in blueprints.BUILDERS]
    if unknown:
        raise SystemExit("no blueprint for: %s (supported: %s)" % (unknown, blueprints.supported_types()))
    raw = os.path.join(args.out, "raw")
    os.makedirs(raw, exist_ok=True)
    setup_scene()
    info = {
        "blender_version": bpy.app.version_string,
        "engine": "BLENDER_EEVEE",
        "samples": SAMPLES,
        "projection_id": iso2x.PROJECTION_ID,
        "canvas_px": [CANVAS, CANVAS],
        "origin_px": [CANVAS / 2.0, CANVAS / 2.0],
        "px_per_m_ortho": iso2x.PX_PER_M_ORTHO,
        "view_transform": "Standard",
        "look": "None",
        "calibration": render_calibration(raw),
        "types": {},
    }
    for type_id in types:
        d = catalog[type_id]
        bp = blueprints.build(d)
        info["types"][type_id] = {"visual_id": d["visual_id"], "rotations": {}}
        os.makedirs(os.path.join(raw, type_id), exist_ok=True)
        for r in range(4):
            clear_models()
            rot = blueprints.rotated(bp, d, r)
            objs = {"body": [], "glass_front": [], "shadow": []}
            for i, b in enumerate(rot["boxes"]):
                objs[b.layer].append(add_box("%s_r%d_%d" % (type_id, r, i), b.x0, b.y0, b.z0, b.x1, b.y1, b.z1, b.material))
            sx0, sy0, sx1, sy1 = rot["shadow"]
            objs["shadow"].append(add_box("%s_r%d_shadow" % (type_id, r), sx0, sy0, 0.0, sx1, sy1, 0.002, "shadow"))
            everything = [o for group in objs.values() for o in group]
            layers = [k for k in ("body", "shadow", "glass_front") if objs[k]]
            for layer in layers:
                render_to(os.path.join(raw, type_id, "r%d_%s.png" % (r, layer)), [(o, o in objs[layer]) for o in everything])
            lo, hi = mesh_bbox_game(objs["body"] + objs["glass_front"])
            info["types"][type_id]["rotations"][str(r)] = {"layers": layers, "mesh_bbox": {"min": lo, "max": hi}}
            print("rendered %s r%d (%s)" % (type_id, r, ",".join(layers)))
    with open(os.path.join(args.out, "render_info.json"), "w", encoding="utf-8") as f:
        json.dump(info, f, ensure_ascii=False, indent=1)
    print("RENDER_DONE")


if __name__ == "__main__":
    main()
