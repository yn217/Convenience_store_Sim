"""Blender: turn a Pixal3D GLB into game fixture body renders (iso2x_v1), one per rotation.

    blender -b -P render_fixture.py -- --glb out/S01_atm.glb --out_dir fixture/atm --type atm \
        --body 0.84 0.84 1.75 --front_yaw 180

The model is stood upright (render_iso.upright), floor splats are removed, then it is scaled into the fixture's body
box (footprint minus 0.04 m on every side x height): one horizontal factor for x and y (its plan keeps its shape) and
its own vertical factor, both from robust (0.5..99.5 %) extents; vertices outside the box are cut away. The box is
centred on the world origin = the centre of the fixture's first tile (1x1 footprints only here).

Rotation r turns the model so its front faces the game edge rotate_edge("S", r) (S -> W -> N -> E); front_yaw is the
yaw that turns the model's front to Blender -Y (= game +Y = S). Each render is a fixed 640x640 canvas with the world
origin at ORIGIN_PX; crop_fixture.py crops it and writes the manifest.
"""
import argparse
import json
import math
import os
import runpy
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

H = runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "render_iso.py"), run_name="render_iso")
PX_PER_M = H["PX_PER_M"]
CANVAS = 640
FRAME_CENTRE_UP_M = 0.8            # the frame centre sits this far up the view plane from the world origin
ORIGIN_PX = [CANVAS / 2, CANVAS / 2 + FRAME_CENTRE_UP_M * PX_PER_M]


def args():
    a = sys.argv[sys.argv.index("--") + 1:]
    p = argparse.ArgumentParser()
    p.add_argument("--glb", required=True)
    p.add_argument("--out_dir", required=True)
    p.add_argument("--type", required=True)
    p.add_argument("--body", type=float, nargs=3, required=True, metavar=("W", "D", "H"))
    p.add_argument("--front_yaw", type=float, default=180.0)
    p.add_argument("--samples", type=int, default=96)
    return p.parse_args(a)


def mesh_points(meshes):
    out = []
    for o in meshes:
        m = np.array(o.matrix_world)
        v = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", v)
        out.append(v.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3])
    return out


def bake_transform(meshes, mat):
    """Applies the 4x4 numpy matrix `mat` to every mesh's world vertices (written back in local space)."""
    for o in meshes:
        m = np.array(o.matrix_world)
        inv = np.linalg.inv(m)
        v = np.empty(len(o.data.vertices) * 3)
        o.data.vertices.foreach_get("co", v)
        w = v.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3]
        w = w @ mat[:3, :3].T + mat[:3, 3]
        loc = w @ inv[:3, :3].T + inv[:3, 3]
        o.data.vertices.foreach_set("co", loc.ravel())
        o.data.update()


def cut_outside(meshes, half_w, half_d, height, eps=0.005):
    removed = 0
    for o, w in zip(meshes, mesh_points(meshes)):
        out = (np.abs(w[:, 0]) > half_w + eps) | (np.abs(w[:, 1]) > half_d + eps) | (w[:, 2] < -eps) | (w[:, 2] > height + eps)
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
    return removed


def main():
    a = args()
    H["reset"]()
    root, meshes = H["import_glb"](a.glb)
    H["setup_render"](a.samples)
    info = {"type": a.type, "glb": a.glb, "body_box_m": a.body, "front_yaw": a.front_yaw}
    info["upright_deg"] = H["upright"](root, meshes)
    meshes = H["drop_fragments"](root, meshes)
    bpy.context.view_layer.update()
    allv = np.concatenate(mesh_points(meshes))
    lo = np.percentile(allv, 0.5, axis=0)
    hi = np.percentile(allv, 99.5, axis=0)
    ext = hi - lo
    # front to Blender -Y first, so x is the width and y the depth of the fixture
    yaw = math.radians(a.front_yaw)
    rz = np.array([[math.cos(yaw), -math.sin(yaw), 0, 0], [math.sin(yaw), math.cos(yaw), 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
    centre = np.eye(4)
    centre[:3, 3] = -np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    bake_transform(meshes, rz @ centre)
    allv = np.concatenate(mesh_points(meshes))
    lo = np.percentile(allv, 0.5, axis=0)
    hi = np.percentile(allv, 99.5, axis=0)
    ext = hi - lo
    bw, bd, bh = a.body
    s_h = min(bw / ext[0], bd / ext[1])
    s_v = bh / ext[2]
    sc = np.diag([s_h, s_h, s_v, 1.0])
    shift = np.eye(4)
    shift[:3, 3] = -np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])
    bake_transform(meshes, sc @ shift)
    info["robust_extent_before_scale_m"] = [round(float(x), 4) for x in ext]
    info["scale_horizontal"] = round(float(s_h), 4)
    info["scale_vertical"] = round(float(s_v), 4)
    info["vertical_over_horizontal"] = round(float(s_v / s_h), 3)
    info["cut_vertices"] = cut_outside(meshes, bw / 2, bd / 2, bh)
    bpy.context.view_layer.update()
    allv = np.concatenate(mesh_points(meshes))
    info["final_bbox_m"] = [np.round(allv.min(axis=0), 4).tolist(), np.round(allv.max(axis=0), 4).tolist()]
    os.makedirs(a.out_dir, exist_ok=True)
    info["renders"] = {}
    base = H["iso_matrix"](Vector((0, 0, 0)))
    view_up = base.to_3x3() @ Vector((0, 1, 0))
    for r in range(4):
        root.rotation_euler = (0, 0, math.radians(-90 * r))   # S -> W -> N -> E as r grows
        bpy.context.view_layer.update()
        m = Matrix.Translation(view_up * FRAME_CENTRE_UP_M) @ base
        cam = H["camera"](m, CANVAS / PX_PER_M, (CANVAS, CANVAS))
        out = os.path.join(a.out_dir, "%s_%d_body_full.png" % (a.type, r))
        bpy.context.scene.render.filepath = out
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam)
        info["renders"][str(r)] = out
    info["origin_px"] = ORIGIN_PX
    with open(os.path.join(a.out_dir, "%s_render_info.json" % a.type), "w") as f:
        json.dump(info, f, indent=2)
    print("INFO", json.dumps(info))


main()
