"""Procedural FULL r0 double-sided gondola comparison asset (Issue #123).

Run with Blender 4.5:
    blender -b --python tools/assets/image_to_3d/blender_gondola_comparator.py -- \
        --out build/issue123-image-to-3d/procedural

This is a visual proposal for review. It deliberately does not alter game contracts,
fixture catalogs, gameplay code, or the approved iso2x camera/scale/pivot setup.
Blender world coordinates map to game coordinates as (x, -y, z), matching
tools/assets/render_fixtures.py. Outputs are limited to the .blend, .glb, one
transparent FULL r0 render, an additional alpha-cropped preview, and metadata in the requested
output folder. The canonical source render remains full canvas and is never cropped in place.
"""
import argparse
import json
import math
import os
import sys
from array import array

import bpy

ASSET_ID = "shelf_general"
BOUNDS = {"min": [-0.46, -0.46, 0.0], "max": [0.46, 1.46, 1.5]}
LEVELS = (0.32, 0.64, 0.96, 1.28)
CANVAS = 1600
SAMPLES = 64
CAMERA_DISTANCE = 30.0


def args_from_blender():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="Output directory for this comparison build")
    return parser.parse_args(argv)


def setup_scene():
    # Keep this camera, light rig, color management, and scale in sync with render_fixtures.py.
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    import iso2x

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if bpy.app.version >= (4, 2, 0) else "BLENDER_EEVEE"
    # Eevee settings moved/changed across Blender releases; only set properties the
    # selected version exposes. The 4.2+ engine is explicitly Eevee Next.
    engine_settings = getattr(scene, "eevee_next", None) or getattr(scene, "eevee", None)
    if engine_settings is not None:
        for prop, value in (("taa_render_samples", SAMPLES), ("taa_samples", SAMPLES),
                            ("use_gtao", False), ("use_ssr", False), ("use_bloom", False),
                            ("use_soft_shadows", True)):
            if hasattr(engine_settings, prop):
                setattr(engine_settings, prop, value)
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = CANVAS
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.dither_intensity = 0.0
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    scene.view_settings.gamma = 1.0
    scene.display_settings.display_device = "sRGB"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    world = bpy.data.worlds.new("iso2x_world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.62, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world
    for name, energy, rot in (("key", 3.0, (50.0, 0.0, -35.0)), ("fill", 1.0, (60.0, 0.0, 125.0))):
        data = bpy.data.lights.new(name, "SUN")
        data.energy = energy
        obj = bpy.data.objects.new(name, data)
        obj.rotation_euler = tuple(math.radians(v) for v in rot)
        scene.collection.objects.link(obj)

    camera = bpy.data.cameras.new("iso2x_v1")
    camera.type = "ORTHO"
    camera.ortho_scale = CANVAS / iso2x.PX_PER_M_ORTHO
    camera.clip_start, camera.clip_end = 0.1, 100.0
    camera.sensor_fit = "AUTO"
    cam_obj = bpy.data.objects.new("iso2x_v1", camera)
    el = math.radians(iso2x.ELEVATION_DEG)
    cam_obj.location = (CAMERA_DISTANCE * math.cos(el) * math.sqrt(0.5),
                        -CAMERA_DISTANCE * math.cos(el) * math.sqrt(0.5),
                        CAMERA_DISTANCE * math.sin(el))
    cam_obj.rotation_euler = (math.radians(90.0 - iso2x.ELEVATION_DEG), 0.0,
                              math.radians(iso2x.AZIMUTH_DEG))
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    return scene, iso2x


MATERIALS = {}
LABEL_MATERIALS = []


def material(name, color, metallic=0.0, roughness=0.5):
    if name in MATERIALS:
        return MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    MATERIALS[name] = mat
    return mat


METAL = SHELF = BASE = RAIL = SPINE = None
PACK = []
ACCENTS = []


def create_materials():
    global METAL, SHELF, BASE, RAIL, SPINE, PACK, ACCENTS, LABEL_MATERIALS
    # Called only after read_factory_settings; Blender removes datablocks on reset.
    MATERIALS.clear()
    METAL = material("powder_coated_cool_gray", (0.38, 0.42, 0.47), 0.68, 0.38)
    SHELF = material("shelf_light_gray", (0.69, 0.73, 0.77), 0.22, 0.43)
    BASE = material("base_charcoal", (0.045, 0.052, 0.062), 0.12, 0.42)
    RAIL = material("price_rail_warm_white", (0.88, 0.84, 0.70), 0.05, 0.48)
    SPINE = material("central_back_panel", (0.53, 0.58, 0.63), 0.18, 0.48)
    PACK = [material("fictional_pack_%02d" % i, c, 0.0, 0.46) for i, c in enumerate((
        (0.78, 0.15, 0.10), (0.10, 0.38, 0.22), (0.96, 0.61, 0.10),
        (0.12, 0.31, 0.66), (0.72, 0.27, 0.47), (0.89, 0.82, 0.60),
        (0.30, 0.20, 0.13), (0.25, 0.64, 0.67))) ]
    ACCENTS = [material("fictional_label_%02d" % i, c, 0.0, 0.5) for i, c in enumerate((
        (0.98, 0.88, 0.54), (0.94, 0.91, 0.82), (0.96, 0.73, 0.25)))]


def create_label_materials(texture_dir):
    global LABEL_MATERIALS
    LABEL_MATERIALS = []
    for index in range(1, 9):
        path = os.path.join(texture_dir, "snack_%02d.png" % index)
        if not os.path.isfile(path):
            raise FileNotFoundError("Package label texture missing: " + path)
        image = bpy.data.images.load(path, check_existing=False)
        image.pack()
        mat = bpy.data.materials.new("fictional_label_texture_%02d" % index)
        mat.diffuse_color = (1.0, 1.0, 1.0, 1.0)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        nodes.clear()
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        tex.interpolation = "Linear"
        tex.extension = "CLIP"
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Strength"].default_value = 0.82
        out = nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
        mat.node_tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        LABEL_MATERIALS.append(mat)


def add_label_plane(name, side, center_y, z0, z1, width, face_x, label_index):
    """UV-map a single graphic card flush to the aisle-facing X surface."""
    x = face_x + side * 0.0008
    y0, y1 = center_y-width/2, center_y+width/2
    verts = [(x, -y0, z0), (x, -y1, z0), (x, -y1, z1), (x, -y0, z1)]
    face = (3, 2, 1, 0) if side > 0 else (0, 1, 2, 3)
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], [face])
    mesh.update()
    uv = mesh.uv_layers.new(name="front_label_uv")
    uv_by_vertex = ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))
    for loop in mesh.loops:
        uv.data[loop.index].uv = uv_by_vertex[loop.vertex_index]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(LABEL_MATERIALS[label_index % len(LABEL_MATERIALS)])
    return obj


def add_box(name, x0, y0, z0, x1, y1, z1, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0+x1)/2, -(y0+y1)/2, (z0+z1)/2))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (x1-x0, y1-y0, z1-z0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("small_edge_softening", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        obj.modifiers.new("weighted_corner_normals", "WEIGHTED_NORMAL")
    return obj


def add_pack(side, y, z, width, height, depth, color_i, shape="box", face_x=None,
             label_index=None):
    """Create one colorful, anonymous package with its display face toward the aisle."""
    face_x = side * 0.375 if face_x is None else face_x
    back_x = face_x - side * depth
    x0, x1 = sorted((face_x, back_x))
    y0, y1 = y - width / 2, y + width / 2
    z0, z1 = z, z + height
    if label_index is None:
        label_index = color_i
    if shape == "cup":
        # Rounded rectangular snack cup with a solid contrasting sealed lid.
        obj = add_box("fictional_cup_%s_%03d" % ("E" if side > 0 else "W", len(bpy.context.scene.objects)),
                      x0, y0, z0, x1, y1, z1, PACK[color_i % len(PACK)],
                      min(width, depth, height)*0.10)
        lid_depth, lid_width = depth*0.94, width*0.94
        lid_center_x = (x0+x1)/2
        add_box("solid_colored_cup_lid", lid_center_x-lid_depth/2, y-lid_width/2, z1-0.012,
                lid_center_x+lid_depth/2, y+lid_width/2, z1+0.002,
                PACK[(color_i+2) % len(PACK)], 0.003)
        add_label_plane("cup_fictional_label", side, y, z+height*.27, z+height*.76,
                        width*.70, face_x, label_index)
        return obj
    obj = add_box("fictional_pack_%s_%03d" % ("E" if side > 0 else "W", len(bpy.context.scene.objects)),
                  x0, y0, z0, x1, y1, z1, PACK[color_i % len(PACK)], 0.004)
    add_label_plane("fictional_food_package_front", side, y, z+height*.08,
                    z+height*.92, width*.84, face_x, label_index)
    return obj


def build_gondola():
    # The requested bounds are exact in game coordinates. Product faces sit inside x=+/-0.46.
    add_box("dark_plinth", -0.46, -0.46, 0.0, 0.46, 1.46, 0.18, BASE, 0.018)
    add_box("central_double_sided_spine", -0.035, -0.46, 0.18, 0.035, 1.46, 1.48, SPINE, 0.004)
    # Narrow spine standards and separate slender end frames; none span across both faces.
    for y in (-0.43, 0.47, 1.43):
        add_box("spine_standard", -0.045, y-0.012, 0.18, 0.045, y+0.012, 1.48, METAL, 0.003)
        for z in (0.24, 0.36, 0.48, 0.60, 0.72, 0.84, 0.96, 1.08, 1.20, 1.32, 1.44):
            add_box("standard_slot", -0.047, y-0.014, z, -0.044, y+0.014, z+0.014, BASE)
    for side in (-1, 1):
        for y in (-0.43, 1.43):
            x = side * 0.405
            add_box("slender_end_frame", x-0.012, y-0.012, 0.18,
                    x+0.012, y+0.012, 1.48, METAL, 0.003)

    # Four bilateral shallow trays. 18 mm decks, with modest front lips and price rails.
    for level_idx, shelf_z in enumerate(LEVELS):
        for side in (-1, 1):
            inner = 0.035 * side
            outer = 0.385 * side  # 0.35 m usable tray depth from the spine face
            x0, x1 = sorted((inner, outer))
            add_box("thin_18mm_shelf_%02d_%s" % (level_idx, "E" if side > 0 else "W"),
                    x0, -0.43, shelf_z-0.009, x1, 1.43, shelf_z+0.009, SHELF, 0.002)
            # Low product stop keeps the facings aligned near the aisle edge.
            lip_x = side * 0.370
            add_box("front_product_stop", lip_x-0.009, -0.43, shelf_z+0.01,
                    lip_x+0.009, 1.43, shelf_z+0.052, METAL, 0.003)
            rail_x = side * 0.382
            add_box("continuous_price_label_rail", rail_x-0.004, -0.43, shelf_z+0.053,
                    rail_x+0.004, 1.43, shelf_z+0.078, RAIL, 0.002)

    # Thin central sign plate leaves the top product facings visible on both sides.
    add_box("central_thin_sign_plate", -0.008, 0.12, 1.34, 0.008, 0.88, 1.50, SHELF, 0.002)

    # Packed facings on every level. Two product rows deepen the shelf while preserving visible fronts.
    for side in (-1, 1):
        for li, shelf_z in enumerate(LEVELS):
            y = -0.395 + (li % 2) * 0.012
            index = 0
            while y < 1.39:
                width = min((0.105, 0.12, 0.09, 0.13, 0.10, 0.115)[(index + li) % 6],
                            1.43 - y)
                gap = 0.006
                front_depth = (0.12, 0.15, 0.105, 0.14)[(index * 3 + li) % 4]
                h = min((0.205, 0.19, 0.22, 0.175)[(index // 3 + li) % 4],
                        1.47 - (shelf_z + 0.009))
                if h > 0.06 and width > gap + 0.02:
                    sku_index = index // 3
                    label_id = (sku_index + li*2 + (0 if side > 0 else 4)) % len(LABEL_MATERIALS)
                    color_id = label_id % len(PACK)
                    kind = "cup" if sku_index % 5 == 4 else "box"
                    add_pack(side, y + width/2, shelf_z+0.009, width-gap, h, front_depth,
                             color_id, kind, face_x=side*0.375, label_index=label_id)
                    # Rear row sits inward from the front row and shares a SKU in small blocks.
                    if index % 2 == 0 and y + width*0.92 <= 1.43:
                        rear_width = width * 0.82
                        add_pack(side, y + width*0.51, shelf_z+0.009, rear_width, h*0.91,
                                 0.115, color_id, "box", face_x=side*0.205,
                                 label_index=label_id)
                y += width + gap
                index += 1


def game_bounds(mesh_objects):
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for obj in mesh_objects:
        for vertex in obj.data.vertices:
            world = obj.matrix_world @ vertex.co
            point = (world.x, -world.y, world.z)
            for axis in range(3):
                lo[axis] = min(lo[axis], point[axis])
                hi[axis] = max(hi[axis], point[axis])
    return {"min": [round(v, 6) for v in lo], "max": [round(v, 6) for v in hi]}


def write_crop_preview(source_path, preview_path, padding=8):
    """Write a separate alpha-bounds preview and return its crop rectangle in source pixels."""
    source = bpy.data.images.load(source_path, check_existing=False)
    width, height = source.size
    rgba = array("f", [0.0]) * (width * height * 4)
    source.pixels.foreach_get(rgba)
    min_x, min_y, max_x, max_y = width, height, -1, -1
    for y in range(height):
        row = y * width * 4
        for x in range(width):
            if rgba[row + x*4 + 3] > (1.0 / 255.0):
                min_x, min_y = min(min_x, x), min(min_y, y)
                max_x, max_y = max(max_x, x), max(max_y, y)
    if max_x < min_x:
        raise RuntimeError("Rendered image has no nontransparent pixels: " + source_path)
    left = max(0, min_x-padding)
    right = min(width, max_x+padding+1)
    bottom = max(0, min_y-padding)
    top = min(height, max_y+padding+1)
    crop_width, crop_height = right-left, top-bottom
    cropped = array("f", [0.0]) * (crop_width * crop_height * 4)
    for row in range(crop_height):
        src_start = ((bottom + row) * width + left) * 4
        dst_start = row * crop_width * 4
        cropped[dst_start:dst_start+crop_width*4] = rgba[src_start:src_start+crop_width*4]
    preview = bpy.data.images.new("shelf_general_FULL_r0_crop_preview", width=crop_width,
                                  height=crop_height, alpha=True, float_buffer=False)
    preview.pixels.foreach_set(cropped)
    preview.file_format = "PNG"
    preview.filepath_raw = preview_path
    preview.save()
    bpy.data.images.remove(source)
    bpy.data.images.remove(preview)
    # Rectangle uses conventional top-left image coordinates: [left, top, right, bottom).
    return [left, height-top, right, height-bottom], [min_x, height-1-max_y, max_x+1, height-min_y]


def configure_cycles_cpu(scene):
    """Headless Ubuntu-F lacks libEGL.so.1, so render with the requested CPU fallback."""
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False


def main():
    args = args_from_blender()
    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)
    scene, iso2x = setup_scene()
    create_materials()
    create_label_materials(os.path.join(out_dir, "textures"))
    build_gondola()
    mesh_objects = [obj for obj in scene.objects if obj.type == "MESH"]
    actual = game_bounds(mesh_objects)
    for axis in range(3):
        if abs(actual["min"][axis] - BOUNDS["min"][axis]) > 0.0001 or abs(actual["max"][axis] - BOUNDS["max"][axis]) > 0.0001:
            raise RuntimeError("Generated bounds %s differ from required %s" % (actual, BOUNDS))

    full_render_path = os.path.join(out_dir, "shelf_general_FULL_r0.png")
    crop_preview_path = os.path.join(out_dir, "shelf_general_FULL_r0_crop_preview.png")
    scene.render.filepath = full_render_path
    # Eevee Next exited at render startup on Ubuntu-F because libEGL.so.1 is absent.
    # Keep the shared iso2x camera, light rig, world, and color management; change only engine.
    configure_cycles_cpu(scene)
    bpy.ops.render.render(write_still=True)
    crop_rect, alpha_bounds = write_crop_preview(full_render_path, crop_preview_path)
    projected_origin = iso2x.project(0.0, 0.0, 0.0)
    anchor_full = [round(CANVAS/2.0 + projected_origin[0], 4),
                   round(CANVAS/2.0 + projected_origin[1], 4)]
    anchor_crop = [round(anchor_full[0] - crop_rect[0], 4),
                   round(anchor_full[1] - crop_rect[1], 4)]
    blend_path = os.path.join(out_dir, "shelf_general_FULL_r0.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    glb_path = os.path.join(out_dir, "shelf_general_FULL_r0.glb")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in mesh_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_objects[0]
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True,
                              export_apply=True, export_cameras=False, export_lights=False)

    metadata = {
        "asset_id": ASSET_ID,
        "build_kind": "procedural_visual_comparison_proposal",
        "runtime_approved": False,
        "state": "FULL",
        "rotation": "r0",
        "front_sides": {"E": "+X", "W": "-X"},
        "front_side_contract_approved": False,
        "coordinate_system": "game (x,y,z); Blender (x,-y,z)",
        "camera_preset": "iso2x_v1",
        "projection_id": iso2x.PROJECTION_ID,
        "canvas_px": [CANVAS, CANVAS],
        "blender_version": bpy.app.version_string,
        "engine": scene.render.engine,
        "samples": scene.cycles.samples,
        "bounds_game_m": actual,
        "required_bounds_game_m": BOUNDS,
        "shelf_levels_z_m": list(LEVELS),
        "fictional_package_textures": ["textures/snack_%02d.png" % i for i in range(1, 9)],
        "alpha_crop_preview": {
            "file": "shelf_general_FULL_r0_crop_preview.png",
            "source_file": "shelf_general_FULL_r0.png",
            "source_unchanged": True,
            "crop_rect_px_top_left_exclusive": crop_rect,
            "alpha_bounds_px_top_left_exclusive": alpha_bounds,
        },
        "anchor_px": {
            "definition": "iso2x_v1 projection of game origin (0,0,0)",
            "full_canvas": anchor_full,
            "crop_preview": anchor_crop,
        },
        "outputs": ["shelf_general_FULL_r0.blend", "shelf_general_FULL_r0.glb",
                    "shelf_general_FULL_r0.png", "shelf_general_FULL_r0_crop_preview.png"],
        "source_reference": "build/issue123-image-to-3d/input/shelf_gondola_design_source.png",
    }
    with open(os.path.join(out_dir, "metadata.json"), "w", encoding="utf-8") as stream:
        json.dump(metadata, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print("WROTE_PROCEDURAL_COMPARISON", out_dir)


if __name__ == "__main__":
    main()
