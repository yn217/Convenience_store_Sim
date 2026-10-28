"""One structural shelf_general FULL r0 comparison pilot (Issues #102/#123).

Run only in the Ubuntu-F Blender 4.5 environment, CPU renderer:
    blender -b --python tools/assets/image_to_3d/blender_gondola_structural_pilot.py -- \
        --out build/issue123-image-to-3d/structural_pilot \
        --textures build/issue123-image-to-3d/procedural/textures

Game coordinates are (x,y,z); Blender coordinates are (x,-y,z). The camera, lights,
world, color management and orthographic scale copy render_fixtures.py / iso2x_v1.
This is a comparison proposal, not a runtime-approved or art-approved asset.
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
SHELF_LEVELS = (0.260, 0.505, 0.750, 0.995, 1.240)
CANVAS = 1600
SAMPLES = 32
CAMERA_DISTANCE = 30.0
SKU_FILES = ["snack_%02d.png" % i for i in range(1, 9)]


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True)
    parser.add_argument("--textures", required=True, help="Existing fictional package label PNG directory")
    return parser.parse_args(argv)


def setup_scene():
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    import iso2x

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = SAMPLES
    scene.cycles.use_denoising = False
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
    for name, energy, rot in (("key", 3.0, (50.0, 0.0, -35.0)),
                              ("fill", 1.0, (60.0, 0.0, 125.0))):
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
    elevation = math.radians(iso2x.ELEVATION_DEG)
    cam_obj.location = (CAMERA_DISTANCE*math.cos(elevation)*math.sqrt(0.5),
                        -CAMERA_DISTANCE*math.cos(elevation)*math.sqrt(0.5),
                        CAMERA_DISTANCE*math.sin(elevation))
    cam_obj.rotation_euler = (math.radians(90.0-iso2x.ELEVATION_DEG), 0.0,
                              math.radians(iso2x.AZIMUTH_DEG))
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    return scene, iso2x


def make_material(name, color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


def make_transparent_film():
    mat = bpy.data.materials.new("clear_bread_bag_film")
    mat.diffuse_color = (0.75, 0.87, 0.93, 0.24)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (0.78, 0.88, 0.94, 1.0)
    shader.inputs["Roughness"].default_value = 0.20
    shader.inputs["Alpha"].default_value = 0.24
    transmission = shader.inputs.get("Transmission Weight") or shader.inputs.get("Transmission")
    if transmission:
        transmission.default_value = 0.12
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = "DITHERED"
    return mat


def build_materials(texture_dir):
    materials = {
        "frame": make_material("gondola_powder_coated_steel", (0.34, 0.39, 0.44), 0.72, 0.38),
        "shelf": make_material("light_gray_thin_steel_shelf", (0.64, 0.69, 0.74), 0.26, 0.44),
        "base": make_material("charcoal_kick_base", (0.035, 0.043, 0.052), 0.12, 0.42),
        "rail": make_material("warm_white_price_rail", (0.88, 0.80, 0.56), 0.03, 0.55),
        "spine": make_material("double_sided_center_back_panel", (0.47, 0.53, 0.59), 0.22, 0.48),
        "bread": make_material("milk_bread_inside_clear_bag", (0.66, 0.37, 0.16), 0.0, 0.72),
        "film": make_transparent_film(),
        "clip": make_material("bread_bag_clips", (0.14, 0.37, 0.28), 0.02, 0.46),
    }
    body_colors = ((0.72, 0.12, 0.07), (0.08, 0.36, 0.20), (0.93, 0.53, 0.08),
                   (0.08, 0.25, 0.61), (0.66, 0.15, 0.36), (0.82, 0.75, 0.52),
                   (0.25, 0.14, 0.08), (0.11, 0.50, 0.52))
    materials["bodies"] = [make_material("package_body_%02d" % i, color, 0.0, 0.64)
                           for i, color in enumerate(body_colors)]
    materials["labels"] = []
    for index, filename in enumerate(SKU_FILES):
        path = os.path.join(texture_dir, filename)
        if not os.path.isfile(path):
            raise FileNotFoundError("Missing existing package texture: " + path)
        image = bpy.data.images.load(path, check_existing=False)
        image.pack()
        mat = bpy.data.materials.new("fictional_food_label_%02d" % (index+1))
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        nodes.clear()
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.interpolation = "Linear"
        texture.extension = "CLIP"
        emission = nodes.new("ShaderNodeEmission")
        emission.inputs["Strength"].default_value = 0.82
        output = nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(texture.outputs["Color"], emission.inputs["Color"])
        mat.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
        materials["labels"].append(mat)
    return materials


def add_box(name, x0, y0, z0, x1, y1, z1, material, bevel=0.0, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0+x1)/2, -(y0+y1)/2, (z0+z1)/2))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (x1-x0, y1-y0, z1-z0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0:
        mod = obj.modifiers.new("soft_package_or_edge_radius", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        obj.modifiers.new("weighted_normals", "WEIGHTED_NORMAL")
    return obj


def add_label_plane(name, side, center_y, z0, z1, width, face_x, material):
    # Plane normal points toward the aisle: +X on the east face, -X on the west face.
    x = face_x + side*0.0007
    y0, y1 = center_y-width/2, center_y+width/2
    verts = [(x, -y0, z0), (x, -y1, z0), (x, -y1, z1), (x, -y0, z1)]
    face = (3, 2, 1, 0) if side > 0 else (0, 1, 2, 3)
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], [face])
    mesh.update()
    uv = mesh.uv_layers.new(name="package_front_uv")
    coords = ((0, 0), (1, 0), (1, 1), (0, 1))
    for loop in mesh.loops:
        uv.data[loop.index].uv = coords[loop.vertex_index]
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_smooth_ellipsoid(name, center_x, center_y, center_z, depth, width, height, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12,
                                         location=(center_x, -center_y, center_z))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (depth/2, width/2, height/2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.data.materials.append(material)
    return obj


def add_package(side, center_y, shelf_z, width, height, depth, shape, label_id, mats,
                face_x, sku_name):
    base_z = shelf_z + 0.009
    top_z = base_z + height
    x_face = side*face_x
    x_back = x_face - side*depth
    x0, x1 = sorted((x_face, x_back))
    y0, y1 = center_y-width/2, center_y+width/2
    body = mats["bodies"][label_id]
    if shape == "pouch":
        # Puffy, rounded snack pouch with a raised crimped heat-seal band.
        add_box("pillow_pouch_body_"+sku_name, x0, y0, base_z, x1, y1, top_z,
                body, min(depth, width, height)*0.24, 4)
        seal_z0 = top_z-height*0.075
        add_box("pouch_top_heat_seal", x0+depth*.06, y0+width*.045, seal_z0,
                x1-depth*.06, y1-width*.045, top_z+0.001, mats["bodies"][(label_id+2)%8],
                min(depth*.12, height*.025), 2)
        # Narrow emboss-like ribs make the sealed edge read as folded film.
        for rib in (-0.30, -0.10, 0.10, 0.30):
            y = center_y + rib*width
            add_box("pouch_seal_rib", x0+depth*.10, y-0.0012, seal_z0+height*.012,
                    x1-depth*.10, y+0.0012, top_z, mats["rail"])
        label_width, label_low, label_high = width*.78, base_z+height*.15, top_z-height*.15
    elif shape == "bread_bag":
        # Bread loaf inside clear film; the front label is a smaller paper patch on the bag.
        cx = (x0+x1)/2
        add_smooth_ellipsoid("soft_milk_bread_loaf", cx, center_y, base_z+height*.47,
                             depth*.72, width*.78, height*.64, mats["bread"])
        add_box("transparent_bread_bag", x0, y0, base_z, x1, y1, top_z,
                mats["film"], min(depth, width, height)*0.12, 3)
        # Folded neck and a small colored bag clip, above the printed patch.
        add_box("folded_clear_bag_neck", x0+depth*.16, center_y-width*.30, top_z-height*.10,
                x1-depth*.16, center_y+width*.30, top_z-height*.035, mats["film"], 0.003, 2)
        add_box("bread_bag_clip", x0+depth*.24, center_y-width*.08, top_z-height*.14,
                x1-depth*.24, center_y+width*.08, top_z-height*.095, mats["clip"], 0.002, 2)
        label_width, label_low, label_high = width*.62, base_z+height*.30, top_z-height*.30
    else:
        # Paperboard carton with low-radius corners and a full, flat print face.
        add_box("paperboard_carton_"+sku_name, x0, y0, base_z, x1, y1, top_z,
                body, min(depth, width, height)*0.055, 2)
        # A slim folded top flap catches light without creating an oversized silhouette.
        add_box("carton_top_fold", x0+depth*.06, y0+width*.06, top_z-height*.025,
                x1-depth*.06, y1-width*.06, top_z+0.001, mats["bodies"][(label_id+1)%8], 0.002, 2)
        label_width, label_low, label_high = width*.84, base_z+height*.07, top_z-height*.07
    add_label_plane("printed_food_front_"+sku_name, side, center_y, label_low, label_high,
                    label_width, x_face, mats["labels"][label_id])


def build_fixture(mats):
    # Dark kick base sets the footprint. The full target bounds remain exactly on this plinth.
    add_box("charcoal_base_plinth", -0.46, -0.46, 0.0, 0.46, 1.46, 0.18,
            mats["base"], 0.016, 3)
    add_box("continuous_double_sided_center_spine", -0.018, -0.46, 0.18,
            0.018, 1.46, 1.48, mats["spine"], 0.003, 2)

    # Narrow standards follow the spine; perimeter end plates close only the run ends.
    for y in (-0.405, 0.51, 1.405):
        add_box("central_spine_upright", -0.038, y-0.012, 0.18,
                0.038, y+0.012, 1.47, mats["frame"], 0.002, 2)
        for z in (0.24, 0.34, 0.44, 0.54, 0.64, 0.74, 0.84, 0.94,
                  1.04, 1.14, 1.24, 1.34, 1.44):
            add_box("upright_adjustment_slot", -0.040, y-0.014, z,
                    -0.038, y+0.014, z+0.012, mats["base"])
    for side in (-1, 1):
        near_x = 0.035*side
        outer_x = 0.425*side
        ex0, ex1 = sorted((near_x, outer_x))
        end_planes = (-0.416, 1.416)
        for y in end_planes:
            # Low kick panel only: the merchandise face above z=0.38 stays open.
            add_box("low_open_end_kick_panel", ex0, y-0.006, 0.18, ex1, y+0.006, 0.38,
                    mats["frame"], 0.002, 2)
            # Thin top-edge brace ties the spine-side and perimeter upright together.
            add_box("open_end_top_edge_brace", ex0, y-0.006, 1.430, ex1, y+0.006, 1.460,
                    mats["frame"], 0.002, 2)
            x = 0.405*side
            add_box("slender_open_end_perimeter_upright", x-0.010, y-0.012, 0.18,
                    x+0.010, y+0.012, 1.460, mats["frame"], 0.003, 2)

    # Five usable bilateral merchandising decks at 24.5 cm centers. The selected
    # maximum 0.22 m pack height leaves about 7 mm before the next 18 mm deck.
    for level_index, shelf_z in enumerate(SHELF_LEVELS):
        for side in (-1, 1):
            x0, x1 = sorted((side*0.038, side*0.385))
            add_box("18mm_shelf_deck_%02d_%s" % (level_index+1, "E" if side > 0 else "W"),
                    x0, -0.425, shelf_z-0.009, x1, 1.425, shelf_z+0.009,
                    mats["shelf"], 0.002, 2)
            # Low 10 mm price rail sits just outside the front edge; minimal product occlusion.
            front0, front1 = sorted((side*0.378, side*0.384))
            add_box("thin_price_rail_%02d" % (level_index+1), front0, -0.425,
                    shelf_z+0.012, front1, 1.425, shelf_z+0.022, mats["rail"], 0.001, 2)

    # Header is fixed to the center spine above the top tier; no products occupy this band.
    add_box("small_center_header_plate", -0.009, 0.20, 1.365, 0.009, 0.82, 1.50,
            mats["shelf"], 0.002, 2)

    # Five stocked levels, both faces. SKU blocks are 2-3 adjacent facings; a single rear
    # row is used sparsely, so depth never exceeds two products. Package dimensions remain
    # within 0.11-0.15 m wide, 0.16-0.23 m tall and 0.035-0.07 m deep.
    product_specs = ((0.118, 0.178, 0.045), (0.132, 0.205, 0.060),
                     (0.145, 0.220, 0.068), (0.126, 0.190, 0.052))
    shape_names = ("pouch", "paper_box", "bread_bag")
    product_count = 0
    rear_count = 0
    for side in (-1, 1):
        for level_index, shelf_z in enumerate(SHELF_LEVELS):
            cursor = -0.405
            group_index = 0
            face_index = 0
            while cursor < 1.405:
                cluster_size = 3 if group_index % 2 == 0 else 2
                label_id = (group_index + level_index*2 + (0 if side > 0 else 4)) % len(SKU_FILES)
                shape = shape_names[(label_id + level_index) % len(shape_names)]
                # A cluster is one SKU: keep its silhouette and physical size fixed.
                width, height, depth = product_specs[(group_index+level_index) % len(product_specs)]
                sku_name = "L%02d_G%02d_S%02d" % (level_index+1, group_index+1, label_id+1)
                for within_cluster in range(cluster_size):
                    if cursor + width > 1.405:
                        cursor = 1.405  # close this row; do not retry a non-fitting SKU forever
                        break
                    center_y = cursor + width/2
                    # Leave tiny gaps between packs for distinct silhouettes and visible labels.
                    add_package(side, center_y, shelf_z, width-0.004, height, depth,
                                shape, label_id, mats, 0.375, sku_name)
                    product_count += 1
                    # One rear facing behind alternating front faces: never a third row.
                    if face_index % 2 == 0 and cursor + width*0.92 <= 1.405:
                        # Same SKU, same shelf plane and dimensions. The .110 m face
                        # offset leaves .042 m clearance even for the deepest pack.
                        add_package(side, center_y, shelf_z, width-0.004, height, depth,
                                    shape, label_id, mats, 0.265, sku_name+"_rear")
                        rear_count += 1
                    cursor += width + 0.004
                    face_index += 1
                group_index += 1
                if face_index == 0:
                    raise RuntimeError("No package fit on shelf level %d" % level_index)
    return product_count, rear_count


def get_game_bounds(mesh_objects):
    low, high = [float("inf")]*3, [float("-inf")]*3
    for obj in mesh_objects:
        for vertex in obj.data.vertices:
            p = obj.matrix_world @ vertex.co
            values = (p.x, -p.y, p.z)
            for axis in range(3):
                low[axis] = min(low[axis], values[axis])
                high[axis] = max(high[axis], values[axis])
    return {"min": [round(v, 6) for v in low], "max": [round(v, 6) for v in high]}


def crop_preview(full_path, crop_path, padding=8):
    source = bpy.data.images.load(full_path, check_existing=False)
    width, height = source.size
    pixels = array("f", [0.0])*(width*height*4)
    source.pixels.foreach_get(pixels)
    min_x, min_y, max_x, max_y = width, height, -1, -1
    for y in range(height):
        row = y*width*4
        for x in range(width):
            if pixels[row+x*4+3] > 1.0/255.0:
                min_x, min_y = min(min_x, x), min(min_y, y)
                max_x, max_y = max(max_x, x), max(max_y, y)
    if max_x < min_x:
        raise RuntimeError("Transparent render contains no visible alpha")
    left, right = max(0, min_x-padding), min(width, max_x+padding+1)
    bottom, top = max(0, min_y-padding), min(height, max_y+padding+1)
    cw, ch = right-left, top-bottom
    crop = array("f", [0.0])*(cw*ch*4)
    for row in range(ch):
        src, dst = ((bottom+row)*width+left)*4, row*cw*4
        crop[dst:dst+cw*4] = pixels[src:src+cw*4]
    image = bpy.data.images.new("shelf_general_FULL_r0_crop", width=cw, height=ch, alpha=True)
    image.pixels.foreach_set(crop)
    image.file_format = "PNG"
    image.filepath_raw = crop_path
    image.save()
    bpy.data.images.remove(source)
    bpy.data.images.remove(image)
    crop_rect = [left, height-top, right, height-bottom]
    alpha_bounds = [min_x, height-1-max_y, max_x+1, height-min_y]
    return crop_rect, alpha_bounds


def main():
    args = parse_args()
    out_dir = os.path.abspath(args.out)
    texture_dir = os.path.abspath(args.textures)
    os.makedirs(out_dir, exist_ok=True)
    scene, iso2x = setup_scene()
    mats = build_materials(texture_dir)
    product_count, rear_count = build_fixture(mats)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    bounds = get_game_bounds(meshes)
    for axis in range(3):
        if abs(bounds["min"][axis]-BOUNDS["min"][axis]) > 0.0001 or \
           abs(bounds["max"][axis]-BOUNDS["max"][axis]) > 0.0001:
            raise RuntimeError("Actual mesh bounds %s do not match requested %s" % (bounds, BOUNDS))

    full_name = "shelf_general_FULL_r0.png"
    crop_name = "shelf_general_FULL_r0_crop.png"
    full_path = os.path.join(out_dir, full_name)
    crop_path = os.path.join(out_dir, crop_name)
    scene.render.filepath = full_path
    bpy.ops.render.render(write_still=True)
    crop_rect, alpha_bounds = crop_preview(full_path, crop_path)
    origin = iso2x.project(0.0, 0.0, 0.0)
    anchor_full = [round(CANVAS/2+origin[0], 4), round(CANVAS/2+origin[1], 4)]
    anchor_crop = [round(anchor_full[0]-crop_rect[0], 4), round(anchor_full[1]-crop_rect[1], 4)]

    blend_name = "shelf_general_FULL_r0.blend"
    glb_name = "shelf_general_FULL_r0.glb"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, blend_name))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, glb_name), export_format="GLB",
                              use_selection=True, export_apply=True,
                              export_cameras=False, export_lights=False)

    metadata = {
        "asset_id": ASSET_ID,
        "build_kind": "structural_comparison_pilot",
        "runtime_approved": False,
        "art_approved": False,
        "state": "FULL",
        "rotation": "r0",
        "front_sides": {"E": "+X", "W": "-X"},
        "front_side_contract_approved": False,
        "coordinate_system": "game (x,y,z); Blender (x,-y,z)",
        "camera_preset": "iso2x_v1",
        "projection_id": iso2x.PROJECTION_ID,
        "source_pixels_per_tile_diamond": list(iso2x.SOURCE_PX_PER_TILE_DIAMOND),
        "canvas_px": [CANVAS, CANVAS],
        "blender_version": bpy.app.version_string,
        "engine": scene.render.engine,
        "device": scene.cycles.device,
        "samples": scene.cycles.samples,
        "bounds_game_m": bounds,
        "required_bounds_game_m": BOUNDS,
        "shelf_levels_z_m": list(SHELF_LEVELS),
        "shelf_count_per_face": len(SHELF_LEVELS),
        "shelf_deck_thickness_m": 0.018,
        "shelf_usable_depth_m": 0.347,
        "endplate_design": {
            "high_solid_wall_removed": True,
            "low_kick_panel_z_m": [0.18, 0.38],
            "top_edge_brace_z_m": [1.43, 1.46],
            "upper_merchandise_faces_open": True,
        },
        "package_dimensions_m": {
            "front_width_range": [0.114, 0.141],
            "height_range": [0.178, 0.220],
            "depth_range": [0.045, 0.068],
        },
        "package_front_normal": {"east_face": "+X", "west_face": "-X"},
        "package_silhouettes": ["rounded_sealed_snack_pouch", "paperboard_carton",
                                 "clear_film_bread_bag_with_loaf"],
        "package_textures": SKU_FILES,
        "product_rows_max": 2,
        "rear_matches_front_dimensions": True,
        "rear_shared_shelf_plane": True,
        "front_rear_face_x_m": [0.375, 0.265],
        "minimum_front_rear_x_clearance_m": 0.042,
        "front_facing_count": product_count,
        "rear_facing_count": rear_count,
        "header_band_contains_products": False,
        "crop": {"file": crop_name, "source_file": full_name,
                 "source_unchanged": True, "padding_px": 8,
                 "crop_rect_px_top_left_exclusive": crop_rect,
                 "alpha_bounds_px_top_left_exclusive": alpha_bounds},
        "anchor_px": {"definition": "iso2x_v1 projection of game origin (0,0,0)",
                      "full_canvas": anchor_full, "crop": anchor_crop},
        "outputs": [blend_name, glb_name, full_name, crop_name],
        "reference_source": "build/issue123-image-to-3d/input/shelf_gondola_design_source.png",
    }
    with open(os.path.join(out_dir, "metadata.json"), "w", encoding="utf-8") as stream:
        json.dump(metadata, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    print("WROTE_STRUCTURAL_PILOT", out_dir)


if __name__ == "__main__":
    main()
