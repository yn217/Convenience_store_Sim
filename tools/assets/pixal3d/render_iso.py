"""Blender: import a Pixal3D GLB, scale it to a target height, and render it in the game's iso2x_v1 projection.

Game projection (scripts/presentation/iso_projection.gd), at 2x source scale:
    u = 128 (x - y),  v_down = 64 (x + y) - 156.77 z
which is an orthographic camera at 30 deg elevation looking along game (-1, -1); 181.02 px per metre on the view plane.
Blender frame: bx = gx, by = -gy, bz = gz (the game frame is left-handed against the screen).

Run:  blender -b -P render_iso.py -- --glb in.glb --out_dir dir --name atm --height 1.8 [--yaws 0,90,180,270]
Writes  <name>_yaw<deg>.png  (transparent, iso2x scale) and  <name>_front.png  (orthographic front check),
and  <name>_info.json  with the fitted size in metres.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

PX_PER_M = 181.02  # 2x source scale on the view plane


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out_dir", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--height", type=float, required=True)
    p.add_argument("--yaws", default="0,90,180,270")
    p.add_argument("--samples", type=int, default=64)
    return p.parse_args(a)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    root = bpy.data.objects.new("root", None)
    bpy.context.scene.collection.objects.link(root)
    for o in bpy.context.scene.objects:
        if o.parent is None and o is not root:
            o.parent = root
    return root, meshes


def world_bbox(meshes):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def drop_fragments(root, meshes, floor_share=0.04, margin=0.03):
    """Delete the flat splats lying on the floor around the object (from the input's floor shadow): vertices within
    `floor_share` of the height above the lowest point that lie outside the footprint (robust xy box, plus `margin`
    of the height) of the vertices above them. Run after upright(). Returns the meshes."""
    import numpy as np
    bpy.context.view_layer.update()
    data = []
    for o in meshes:
        m = np.array(o.matrix_world)
        v = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", v)
        data.append(v.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3])
    allv = np.concatenate(data)
    z0, z1 = np.percentile(allv[:, 2], 0.2), np.percentile(allv[:, 2], 99.9)
    low_z = z0 + floor_share * (z1 - z0)
    upper = allv[allv[:, 2] > z0 + 0.1 * (z1 - z0)]
    pad = margin * (z1 - z0)
    xlo, ylo = np.percentile(upper[:, :2], 0.5, axis=0) - pad
    xhi, yhi = np.percentile(upper[:, :2], 99.5, axis=0) + pad
    removed = 0
    for o, w in zip(meshes, data):
        outside = (w[:, 0] < xlo) | (w[:, 0] > xhi) | (w[:, 1] < ylo) | (w[:, 1] > yhi)
        out = (w[:, 2] < low_z) & outside
        # floating specks anywhere: outside the robust box by more than the padding again
        far = (w[:, 0] < xlo - pad) | (w[:, 0] > xhi + pad) | (w[:, 1] < ylo - pad) | (w[:, 1] > yhi + pad)
        out |= far | (w[:, 2] < z0 - pad) | (w[:, 2] > z1 + pad)
        if not out.any():
            continue
        removed += int(out.sum())
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        o.data.vertices.foreach_set("select", out.tolist())
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.delete(type="VERT")
        bpy.ops.object.mode_set(mode="OBJECT")
    print("FRAGMENTS removed vertices:", removed)
    return meshes


def upright(root, meshes):
    """Pixal3D leaves the object in the input camera's frame, so a photo taken from slightly above gives a leaning
    model. Search pitch/roll/yaw for the smallest bounding box: a boxy fixture then stands upright and axis-aligned."""
    import numpy as np
    bpy.context.view_layer.update()
    pts = []
    for o in meshes:
        m = np.array(o.matrix_world)
        v = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", v)
        v = v.reshape(-1, 3)
        v = v[:: max(1, len(v) // 20000)]
        pts.append(v @ m[:3, :3].T + m[:3, 3])
    p = np.concatenate(pts)
    p = p - p.mean(axis=0)

    def rot(rx, ry, rz):
        cx, sx, cy, sy, cz, sz = np.cos(rx), np.sin(rx), np.cos(ry), np.sin(ry), np.cos(rz), np.sin(rz)
        mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
        my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
        mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
        return mz @ my @ mx

    def volume(r):
        q = p @ r.T
        # robust extent (ignores stray splats under the object)
        lo = np.percentile(q, 0.5, axis=0)
        hi = np.percentile(q, 99.5, axis=0)
        return float(np.prod(hi - lo))

    best = (volume(np.eye(3)), 0.0, 0.0, 0.0)
    # pitch/roll within +-40 deg (the photo's camera tilt); yaw over a full quarter turn (a box repeats every 90 deg)
    for step, span, zspan in ((math.radians(4), math.radians(40), math.radians(48)),
                              (math.radians(1), math.radians(4), math.radians(4)),
                              (math.radians(0.25), math.radians(1), math.radians(1))):
        _, bx, by, bz = best
        rng = np.arange(-span, span + 1e-9, step)
        zrng = np.arange(-zspan, zspan + 1e-9, step)
        for rx in bx + rng:
            for ry in by + rng:
                for rz in bz + zrng:
                    v = volume(rot(rx, ry, rz))
                    if v < best[0]:
                        best = (v, rx, ry, rz)
    _, rx, ry, rz = best
    root.rotation_mode = "XYZ"
    r = Matrix(rot(rx, ry, rz).tolist()).to_4x4()
    for o in [c for c in root.children]:
        o.matrix_world = r @ o.matrix_world
    bpy.context.view_layer.update()
    return [math.degrees(rx), math.degrees(ry), math.degrees(rz)]


def fit(root, meshes, height):
    bpy.context.view_layer.update()
    lo, hi = world_bbox(meshes)
    s = height / (hi.z - lo.z)
    root.scale = (s, s, s)
    bpy.context.view_layer.update()
    lo, hi = world_bbox(meshes)
    centre = (lo + hi) / 2
    root.location -= Vector((centre.x, centre.y, lo.z))   # footprint centre on the origin, base on the floor
    bpy.context.view_layer.update()
    return world_bbox(meshes)


def setup_render(samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = d.type == "CUDA"
    sc.cycles.device = "GPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.2
    sun.angle = math.radians(25)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(40), math.radians(10), math.radians(-30))
    sc.collection.objects.link(so)


def camera(matrix, ortho_scale, res):
    sc = bpy.context.scene
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = ortho_scale
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    co.matrix_world = matrix
    sc.camera = co
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    return co


def iso_matrix(target, dist=20.0):
    r = Vector((1, 1, 0)).normalized()
    f = Vector((-math.cos(math.radians(30)) / math.sqrt(2), math.cos(math.radians(30)) / math.sqrt(2), -0.5))
    u = r.cross(-f)   # right x back = up for a right-handed camera
    u = -u if u.z < 0 else u
    pos = target - f * dist
    m = Matrix((r, u, -f)).transposed().to_4x4()
    m.translation = pos
    return m


def project(m_cam, p):
    """View-plane coordinates (metres) of point p for camera matrix m_cam: (right, up)."""
    inv = m_cam.inverted()
    q = inv @ p
    return q.x, q.y


def main():
    a = args()
    reset()
    root, meshes = import_glb(a.glb)
    setup_render(a.samples)
    os.makedirs(a.out_dir, exist_ok=True)
    info = {"name": a.name, "glb": a.glb, "height_m": a.height, "renders": {}}
    info["upright_deg"] = upright(root, meshes)
    meshes = drop_fragments(root, meshes)
    lo, hi = fit(root, meshes, a.height)
    info["size_m_yaw0"] = [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)]
    for yaw in [int(y) for y in a.yaws.split(",")]:
        root.rotation_euler = (0, 0, math.radians(yaw))
        bpy.context.view_layer.update()
        lo, hi = world_bbox(meshes)
        target = Vector((0, 0, 0))
        m = iso_matrix(target)
        # canvas: project the 8 bbox corners, pad, keep the world origin (footprint centre on the floor) as anchor
        pts = [project(m, Vector((x, y, z))) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        half_w = max(abs(min(xs)), abs(max(xs))) + 0.05
        top, bottom = max(ys) + 0.05, min(ys) - 0.05
        w_px = int(math.ceil(2 * half_w * PX_PER_M))
        h_px = int(math.ceil((top - bottom) * PX_PER_M))
        # centre the ortho frame on (0, (top + bottom) / 2) in view space
        shift = Matrix.Translation(m.to_3x3() @ Vector((0, (top + bottom) / 2, 0)))
        cam = camera(shift @ m, max(w_px, h_px) / PX_PER_M, (w_px, h_px))
        out = os.path.join(a.out_dir, f"{a.name}_yaw{yaw}.png")
        bpy.context.scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        info["renders"][str(yaw)] = {"png": out, "canvas_px": [w_px, h_px],
                                     "anchor_px": [w_px / 2, round(top * PX_PER_M, 1)],
                                     "size_m": [round(hi.x - lo.x, 3), round(hi.y - lo.y, 3), round(hi.z - lo.z, 3)]}
        bpy.data.objects.remove(cam)
    # orthographic front check (looking along +Y at yaw 0)
    root.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    lo, hi = world_bbox(meshes)
    for label, rot, loc in (("front", (math.radians(90), 0, 0), (0, -20, (hi.z) / 2)),
                            ("side", (math.radians(90), 0, math.radians(90)), (20, 0, (hi.z) / 2))):
        m = Matrix.LocRotScale(Vector(loc), __import__("mathutils").Euler(rot), None)
        size = max(hi.x - lo.x, hi.y - lo.y, hi.z - lo.z) * 1.1
        res = int(size * 300)
        cam = camera(m, size, (res, res))
        out = os.path.join(a.out_dir, f"{a.name}_{label}.png")
        bpy.context.scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam)
    with open(os.path.join(a.out_dir, f"{a.name}_info.json"), "w") as f:
        json.dump(info, f, indent=2)
    print("INFO", json.dumps(info))


if __name__ == "__main__":
    main()
