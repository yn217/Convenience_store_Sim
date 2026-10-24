"""Normalize and inspect a fused shelf GLB, then save Blender and diagnostic renders.

Run with Blender 4.5:
  blender -b --python normalize_render_glb.py -- --input fused.glb --out output \
    [--front-axis +Y --up-axis +Z]

Axes describe directions in Blender world space AFTER the GLB importer has converted glTF axes.
They are provided hypotheses, not an automatic recognition of the shelf front or up. If omitted, no orientation correction is applied and the
report explicitly marks orientation UNKNOWN. Bounding-box fitting is dimensional normalization,
not evidence that fused or unclassified shelf parts are structurally correct.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

TARGET = (0.92, 1.92, 1.50)  # shelf_general x, y, z in metres
CANVAS = 1200
CAMERA_DISTANCE = 30.0
Z_PX_PER_M = 156.76734354
PX_PER_M_ORTHO = 128.0 * math.sqrt(2.0)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--front-axis", help="Post-import Blender-world signed front hypothesis, e.g. +Y or -X")
    p.add_argument("--up-axis", help="Post-import Blender-world signed up hypothesis, e.g. +Z")
    return p.parse_args(argv)


def axis_vector(value):
    if not value:
        return None
    value = value.strip().upper()
    sign = -1.0 if value.startswith("-") else 1.0
    letter = value[-1:]
    if letter not in "XYZ" or value not in ("+X", "-X", "X", "+Y", "-Y", "Y", "+Z", "-Z", "Z"):
        raise ValueError("axis must be one of +X, -X, +Y, -Y, +Z, -Z")
    v = Vector((0.0, 0.0, 0.0))
    v["XYZ".index(letter)] = sign
    return v


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bounds(objects):
    bpy.context.view_layer.update()
    # Callers may pass the complete imported hierarchy, which can contain EMPTY roots.
    # Only mesh geometry contributes to bounds; non-mesh nodes have no vertex data.
    meshes = [o for o in objects if getattr(o, "type", None) == "MESH"
              and getattr(o, "data", None) is not None]
    points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    if not points:
        raise RuntimeError("Imported scene contains no mesh vertices")
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    return lo, hi


def orient_roots(objects, front, up):
    if front is None or up is None:
        return "UNKNOWN"
    if abs(front.dot(up)) > 1e-6:
        raise ValueError("--front-axis and --up-axis must be perpendicular")
    object_set = set(objects)
    roots = [o for o in objects if o.parent is None or o.parent not in object_set]
    # Shelf front is game +X. render_fixtures maps game (x, y, z) to Blender (x, -y, z).
    src_front = front.normalized()
    src_up = up.normalized()
    src_right = src_front.cross(src_up).normalized()
    dst_front = Vector((1.0, 0.0, 0.0))
    dst_up = Vector((0.0, 0.0, 1.0))
    dst_right = dst_front.cross(dst_up).normalized()
    src_basis = Matrix((src_right, src_front, src_up)).transposed()
    dst_basis = Matrix((dst_right, dst_front, dst_up)).transposed()
    rotation = dst_basis @ src_basis.transposed()
    pivot = Vector(bounds(objects)[0])
    for obj in roots:
        obj.matrix_world = Matrix.Translation(pivot) @ rotation.to_4x4() @ Matrix.Translation(-pivot) @ obj.matrix_world
    return "EXPLICIT"


def configure_scene():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.render.resolution_x = scene.render.resolution_y = CANVAS
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    world = bpy.data.worlds.new("fused_shelf_world") if not bpy.data.worlds else bpy.data.worlds[0]
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.62, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    for name, energy, rot in (("key", 3.0, (50.0, 0.0, -35.0)), ("fill", 1.0, (60.0, 0.0, 125.0))):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        obj = bpy.data.objects.new(name, data)
        scene.collection.objects.link(obj)
        obj.rotation_euler = tuple(math.radians(a) for a in rot)


def make_camera(name, location, target, ortho_scale):
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = ortho_scale
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def render_views(out, lo, hi):
    scene = bpy.context.scene
    center = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2))
    size = Vector((hi[i] - lo[i] for i in range(3)))
    # Match render_fixtures.py / iso2x_v1: origin pivot, 30 deg elevation, 45 deg azimuth,
    # 30 m camera distance and exact orthographic pixel scale.
    el = math.radians(30.0)
    iso = make_camera("iso2x_v1_r0", Vector((CAMERA_DISTANCE * math.cos(el) / math.sqrt(2),
                         -CAMERA_DISTANCE * math.cos(el) / math.sqrt(2), CAMERA_DISTANCE * math.sin(el))),
                      (0.0, 0.0, 0.0), CANVAS / PX_PER_M_ORTHO)
    scene.camera = iso
    scene.render.filepath = os.path.join(out, "iso2x_r0.png")
    bpy.ops.render.render(write_still=True)
    diagnostics = {
        "front": (Vector((1, 0, 0)), max(size.y, size.z) * 1.15),
        "back": (Vector((-1, 0, 0)), max(size.y, size.z) * 1.15),
        "left": (Vector((0, 1, 0)), max(size.x, size.z) * 1.15),
        "right": (Vector((0, -1, 0)), max(size.x, size.z) * 1.15),
    }
    for name, (direction, scale) in diagnostics.items():
        cam = make_camera("diagnostic_" + name, center + direction * CAMERA_DISTANCE, center, max(scale, 0.1))
        scene.camera = cam
        scene.render.filepath = os.path.join(out, name + ".png")
        bpy.ops.render.render(write_still=True)
    return iso


def main():
    args = parse_args()
    src = os.path.abspath(args.input)
    out = os.path.abspath(args.out)
    if not os.path.isfile(src):
        raise SystemExit("input GLB not found: " + src)
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    imported_objects = list(bpy.context.scene.objects)
    objects = mesh_objects()
    if not objects:
        raise SystemExit("GLB import produced no meshes")
    source_lo, source_hi = bounds(objects)
    front, up = axis_vector(args.front_axis), axis_vector(args.up_axis)
    if (front is None) != (up is None):
        raise SystemExit("provide both --front-axis and --up-axis, or omit both to record UNKNOWN")
    orientation = orient_roots(imported_objects, front, up)
    raw_lo, raw_hi = bounds(objects)
    raw_size = [raw_hi[i] - raw_lo[i] for i in range(3)]
    if any(x <= 1e-9 for x in raw_size):
        raise SystemExit("cannot normalize zero-extent mesh dimension: " + repr(raw_size))
    scale = [TARGET[i] / raw_size[i] for i in range(3)]
    root = bpy.data.objects.new("shelf_general_normalization_root", None)
    bpy.context.scene.collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"
    imported_set = set(imported_objects)
    hierarchy_roots = [o for o in imported_objects if o.parent is None or o.parent not in imported_set]
    for obj in hierarchy_roots:
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
    root.scale = scale
    raw_center = Vector(tuple((raw_lo[i] + raw_hi[i]) / 2 for i in range(3)))
    # Blender coordinates are (game x, -game y, z): target bounds are
    # x[-.46,.46], y[-1.46,.46], z[0,1.5], center (0,-.5,.75).
    root.location = Vector((-raw_center.x * scale[0], -0.50 - raw_center.y * scale[1], -raw_lo[2] * scale[2]))
    bpy.context.view_layer.update()
    final_lo, final_hi = bounds(objects)

    meshes_report = []
    for obj in objects:
        meshes_report.append({"object": obj.name, "vertices": len(obj.data.vertices),
                              "polygons": len(obj.data.polygons), "uv_layers": [u.name for u in obj.data.uv_layers],
                              "materials": [m.name if m else None for m in obj.data.materials]})
    images = []
    for image in bpy.data.images:
        try:
            image.pack()
        except RuntimeError:
            pass
        images.append({"name": image.name, "size": list(image.size), "packed": bool(image.packed_file)})
    for mat in bpy.data.materials:
        if mat.node_tree:
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image and node.image.packed_file is None:
                    node.image.pack()

    configure_scene()
    iso_camera = render_views(out, final_lo, final_hi)
    bpy.context.scene.camera = iso_camera
    # Save the native scene after camera creation so it opens ready for inspection.
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "shelf_gondola.blend"))
    # Export only imported hierarchy and normalization root; cameras/lights are not part of GLB.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in imported_objects + [root]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "normalized.glb"), export_format="GLB",
                              use_selection=True, export_materials="EXPORT", export_cameras=False,
                              export_lights=False)
    report = {
        "blender_version": bpy.app.version_string,
        "input": src,
        "target_type": "shelf_general",
        "orientation": {"status": orientation, "front_axis": args.front_axis, "up_axis": args.up_axis,
                        "axes_space": "Blender world AFTER glTF import", "physical_front_verified": False},
        "raw_bounds": {"min": source_lo, "max": source_hi,
                       "dimensions": [source_hi[i] - source_lo[i] for i in range(3)]},
        "oriented_pre_normalization_bounds": {"min": raw_lo, "max": raw_hi, "dimensions": raw_size},
        "target_dimensions_m": list(TARGET),
        "normalization_scale_xyz": scale,
        "anisotropic_distortion": {"axis_scale_ratio_max_min": max(scale) / min(scale),
                                   "per_axis_scale": scale,
                                   "physical_layout_preserved": False,
                                   "interpretation": "Independent axis fitting changes source proportions and physical geometry."},
        "raw_geometry_physical_layout_exact": False,
        "normalized_bounds": {"min": final_lo, "max": final_hi},
        "normalized_anchor": {"world_origin": [0.0, 0.0, 0.0], "canvas_origin_px": [CANVAS / 2, CANVAS / 2],
                              "iso2x_blender_axis_projection_px_per_m": {
                                  "x": [128.0, 64.0], "y": [128.0, -64.0], "z": [0.0, -Z_PX_PER_M]},
                              "target_local_center_blender_m": [0.0, -0.5, 0.75]},
        "meshes": meshes_report,
        "materials": [m.name for m in bpy.data.materials],
        "images": images,
        "runtime_approved": False,
        "structural_checks": {"status": "UNKNOWN", "reason": "Fused or unclassified shelf parts cannot be verified by bounding-box normalization."},
        "bbox_fit_proves_shell_correctness": False,
        "outputs": ["normalized.glb", "shelf_gondola.blend", "front.png", "back.png", "left.png", "right.png", "iso2x_r0.png"],
    }
    with open(os.path.join(out, "report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("NORMALIZE_RENDER_GLB_DONE")


if __name__ == "__main__":
    main()
