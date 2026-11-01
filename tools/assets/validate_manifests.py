"""Mechanical gate for generated fixture sprites (06 §6, Issue #8). Exit code 0 = PASS.

    python tools/assets/validate_manifests.py [--dir assets/generated/fixtures] [--catalog data/fixtures/mvp_v1.json]

Checks (no network, no Blender needed; needs Pillow + numpy):
  * camera calibration from the committed calibration PNG: +X (+128,+64), +Y (-128,+64) within 1 px,
    +Z (0,-156.767) within 2 px (source px)
  * manifest structure == visual_manifest.schema.json (additionalProperties=false etc.)
  * referenced PNGs exist inside the manifest folder, are RGBA, and every layer of a direction has
    the manifest canvas size; anchors / slots / polygon / sorting anchor lie inside the canvas
  * >= 8 px padding around the sprite; image sizes may differ between assets (that is fine)
  * rendered silhouette vs projected blueprint (ground contact, <= 2 source px = 1 screen px @ zoom 1)
  * footprint / dimensions == catalog; blueprint + measured Blender mesh bbox obey the size rules
  * the slot anchors sit toward the fixture's customer-facing side
"""
import argparse
import glob
import json
import math
import os
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blueprints  # noqa: E402
import iso2x  # noqa: E402

PNG_NAME = re.compile(r"^(?!/)(?!.*\.\.)(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.png$")
ID = re.compile(r"^[a-z][a-z0-9_]*$")
LAYER_KEYS = {"body", "shadow", "glass_front", "fixture_back", "fixture_front"}
ROT_KEYS = {"canvas_px", "anchor_px", "layers", "slot_anchors_px", "selection_polygon_px", "sorting_anchor_px"}
TOP_KEYS = {"manifest_version", "visual_id", "fixture_type_id", "projection_id", "world_units_per_tile",
            "source_px_per_tile_diamond", "footprint", "dimensions_m", "rotations",
            "variant", "state", "runtime_approved"}
TOP_REQUIRED = {"manifest_version", "visual_id", "fixture_type_id", "projection_id", "world_units_per_tile",
                "source_px_per_tile_diamond"}
GROUND_TOL_PX = 2.0     # source px; 1 screen px at zoom 1.0
## Model-derived fixtures: feet, casters and plinths sit inside the envelope's front corner (about 0.1-0.2 m), so the
## lowest silhouette pixel may stay this far above it. The model itself is placed on z = 0 by render_fixture.py.
MODEL_GROUND_TOL_PX = 32.0
# Idol models whose envelope's near corner is open floor: chairs and stools on legs, a shelf
# standing back from its footprint's corner. Their lowest opaque pixel sits further above the ground point.
MODEL_GROUND_TOL_OPEN_PX = {"eat_in_table": 64.0, "eat_in_counter": 48.0, "capsule_toy_3": 48.0, "shelf_goods": 48.0}
PADDING_PX = 8


def is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v)


def is_pair(v, integer=False):
    return (isinstance(v, list) and len(v) == 2
            and all((isinstance(x, int) and not isinstance(x, bool)) if integer else is_num(x) for x in v))


def structure_errors(m, path="manifest"):
    """Structure checks mirroring docs/schemas/visual_manifest.schema.json."""
    e = []
    if not isinstance(m, dict):
        return ["%s: not an object" % path]
    for k in sorted(TOP_REQUIRED - set(m)):
        e.append("%s: missing %s" % (path, k))
    for k in sorted(set(m) - TOP_KEYS):
        e.append("%s: unknown field %s" % (path, k))
    if m.get("manifest_version") != 1:
        e.append("%s: manifest_version must be 1" % path)
    for k in ("visual_id", "fixture_type_id"):
        if k in m and not (isinstance(m[k], str) and ID.match(m[k])):
            e.append("%s: %s is not a stable id" % (path, k))
    if m.get("projection_id") != iso2x.PROJECTION_ID:
        e.append("%s: projection_id must be iso2x_v1" % path)
    if m.get("world_units_per_tile") != 1:
        e.append("%s: world_units_per_tile must be 1" % path)
    if m.get("source_px_per_tile_diamond") != [256, 128]:
        e.append("%s: source_px_per_tile_diamond must be [256, 128]" % path)
    fp = m.get("footprint")
    if fp is not None and not (isinstance(fp, dict) and set(fp) == {"w", "h"} and all(isinstance(fp[k], int) and fp[k] >= 1 for k in fp)):
        e.append("%s: bad footprint" % path)
    dm = m.get("dimensions_m")
    if dm is not None and not (isinstance(dm, dict) and set(dm) == {"width", "depth", "height"} and all(is_num(v) and v > 0 for v in dm.values())):
        e.append("%s: bad dimensions_m" % path)
    rots = m.get("rotations")
    if rots is not None:
        if not isinstance(rots, dict) or set(rots) - {"0", "1", "2", "3"}:
            e.append("%s: rotations must be a subset of 0..3" % path)
        else:
            for rk, r in rots.items():
                e += _rotation_structure(r, "%s.rotations.%s" % (path, rk))
    return e


def _rotation_structure(r, path):
    e = []
    if not isinstance(r, dict):
        return ["%s: not an object" % path]
    for k in sorted(ROT_KEYS - {"slot_anchors_px", "selection_polygon_px", "sorting_anchor_px"} - set(r)):
        e.append("%s: missing %s" % (path, k))
    for k in sorted(set(r) - ROT_KEYS):
        e.append("%s: unknown field %s" % (path, k))
    if "canvas_px" in r and not (is_pair(r["canvas_px"], True) and min(r["canvas_px"]) >= 1):
        e.append("%s: bad canvas_px" % path)
    for k in ("anchor_px", "sorting_anchor_px"):
        if k in r and not is_pair(r[k]):
            e.append("%s: bad %s" % (path, k))
    layers = r.get("layers")
    if isinstance(layers, dict):
        if "body" not in layers:
            e.append("%s: layers.body is required" % path)
        for k, v in layers.items():
            if k not in LAYER_KEYS:
                e.append("%s: unknown layer %s" % (path, k))
            elif not (isinstance(v, str) and PNG_NAME.match(v)):
                e.append("%s: layer %s path is unsafe or not a .png" % (path, k))
    elif "layers" in r:
        e.append("%s: layers not an object" % path)
    if "slot_anchors_px" in r:
        s = r["slot_anchors_px"]
        if not isinstance(s, dict) or not all(is_pair(v) for v in s.values()):
            e.append("%s: bad slot_anchors_px" % path)
    if "selection_polygon_px" in r:
        p = r["selection_polygon_px"]
        if not (isinstance(p, list) and len(p) >= 3 and all(is_pair(v) for v in p)):
            e.append("%s: bad selection_polygon_px" % path)
    return e


def load_rgba(path):
    with Image.open(path) as img:
        if img.mode != "RGBA":
            raise ValueError("%s is %s, not RGBA" % (os.path.basename(path), img.mode))
        return np.array(img)


def calibration_errors(prov, base):
    """Measure the calibration render (06 §5.3): no calibrated camera, no assets."""
    errs = []
    cal = prov.get("calibration", {})
    path = os.path.join(base, cal.get("file", "missing"))
    if not os.path.isfile(path):
        return ["calibration image missing: %s" % path]
    arr = load_rgba(path).astype(float)
    a = arr[..., 3]
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    masks = {
        "marker_o": (r > 200) & (g > 200) & (b > 200) & (a > 200),
        "marker_x": (r > 200) & (g < 60) & (b < 60) & (a > 200),
        "marker_y": (g > 200) & (r < 60) & (b < 60) & (a > 200),
        "marker_z": (b > 200) & (r < 60) & (g < 60) & (a > 200),
    }
    pts = {}
    for k, m in masks.items():
        ys, xs = np.nonzero(m)
        if len(xs) == 0:
            return ["calibration marker %s not found in the image" % k]
        w = a[ys, xs]
        pts[k] = (float(((xs + 0.5) * w).sum() / w.sum()), float(((ys + 0.5) * w).sum() / w.sum()))
    o = pts["marker_o"]
    expect = {"marker_x": ((128.0, 64.0), 1.0), "marker_y": ((-128.0, 64.0), 1.0), "marker_z": ((0.0, -iso2x.Z_PX_PER_M), 2.0)}
    for k, (want, tol) in expect.items():
        got = (pts[k][0] - o[0], pts[k][1] - o[1])
        if abs(got[0] - want[0]) > tol or abs(got[1] - want[1]) > tol:
            errs.append("calibration %s: measured %.2f,%.2f expected %.2f,%.2f (tol %.1f px)" % (k, got[0], got[1], want[0], want[1], tol))
    origin = prov.get("origin_px", [0, 0])
    if abs(o[0] - origin[0]) > 1.0 or abs(o[1] - origin[1]) > 1.0:
        errs.append("calibration origin %.2f,%.2f differs from render origin %s" % (o[0], o[1], origin))
    return errs


def silhouette_errors(d, r, rot, base):
    """Rendered opaque body extent vs the projected blueprint extent, relative to the anchor."""
    bp = blueprints.rotated(blueprints.build(d), d, r)
    pts = [iso2x.project(x, y, z) for b in bp["boxes"] if b.layer == "body" for (x, y, z) in b.corners()]
    want = (min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts), max(p[1] for p in pts))
    arr = load_rgba(os.path.join(base, rot["layers"]["body"]))
    ys, xs = np.nonzero(arr[..., 3] >= 128)
    ax, ay = rot["anchor_px"]
    got = (xs.min() - ax, ys.min() - ay, xs.max() + 1 - ax, ys.max() + 1 - ay)
    errs = []
    if blueprints.is_model_type(d["type_id"]):
        # a model cut to its envelope: inside it on every side, and standing on the floor (bottom edge close)
        for name, g, w, sign in zip(("left", "top", "right", "bottom"), got, want, (1, 1, -1, -1)):
            if sign * (g - w) < -GROUND_TOL_PX:
                errs.append("%s r%d: %s edge %.1f px outside the body envelope" % (d["type_id"], r, name, g - w))
        tol = MODEL_GROUND_TOL_OPEN_PX.get(d["type_id"], MODEL_GROUND_TOL_PX)
        if want[3] - got[3] > tol:
            errs.append("%s r%d: bottom edge %.1f px above the ground point (> %.1f)" % (d["type_id"], r, want[3] - got[3], tol))
        return errs
    for name, g, w in zip(("left", "top", "right", "bottom"), got, want):
        if abs(g - w) > GROUND_TOL_PX:
            errs.append("%s r%d: %s edge %.1f px from the projected blueprint (> %.1f)" % (d["type_id"], r, name, g - w, GROUND_TOL_PX))
    return errs


def front_side_errors(d, r, rot):
    errs = []
    if not d["access_edges"] or not rot.get("slot_anchors_px"):
        return errs
    bp = blueprints.rotated(blueprints.build(d), d, r)
    lo, hi = blueprints.mesh_bbox(bp["boxes"])
    cx, cy = (lo[0] + hi[0]) / 2.0, (lo[1] + hi[1]) / 2.0
    pts = [p for items in bp["slots"].values() for _i, p in items]
    sx = sum(p[0] for p in pts) / len(pts) - cx
    sy = sum(p[1] for p in pts) / len(pts) - cy
    if math.hypot(sx, sy) < 1e-6:
        return errs
    vec = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0)}
    if len(d["access_edges"]) == 1:
        e = iso2x.rotate_edge(d["access_edges"][0], r)
        if sx * vec[e][0] + sy * vec[e][1] <= 0:
            errs.append("%s r%d: display slots are not on the %s (customer) side" % (d["type_id"], r, e))
    return errs


def mesh_errors(d, prov):
    errs = list(blueprints.problems(d))
    bbox = prov.get("mesh_bbox", {}).get(d["type_id"])
    if not bbox:
        return errs + ["%s: no measured mesh bbox in PROVENANCE.json" % d["type_id"]]
    w, h = d["footprint"]["w"], d["footprint"]["h"]
    for r in range(4):
        m = bbox.get(str(r))
        if not m:
            errs.append("%s r%d: missing mesh bbox" % (d["type_id"], r))
            continue
        rw, rh = (w, h) if r % 2 == 0 else (h, w)
        sx, sy, sz = (m["max"][i] - m["min"][i] for i in range(3))
        if sx > rw - 0.08 + 1e-4 or sy > rh - 0.08 + 1e-4:
            errs.append("%s r%d: Blender mesh %.3f x %.3f exceeds footprint-0.08 m" % (d["type_id"], r, sx, sy))
        if abs(sz - d["dimensions_m"]["height"]) > 0.01:
            errs.append("%s r%d: Blender mesh height %.3f != %.3f +/- 0.01" % (d["type_id"], r, sz, d["dimensions_m"]["height"]))
        rx0, ry0, rx1, ry1 = iso2x.rotated_footprint_rect(w, h, r)
        if m["min"][0] < rx0 + 0.04 - 1e-4 or m["min"][1] < ry0 + 0.04 - 1e-4 or m["max"][0] > rx1 - 0.04 + 1e-4 or m["max"][1] > ry1 - 0.04 + 1e-4:
            errs.append("%s r%d: Blender mesh leaves the footprint-0.04 m body box" % (d["type_id"], r))
        lo, hi = blueprints.mesh_bbox(blueprints.rotated(blueprints.build(d), d, r)["boxes"])
        for i in range(3):
            if abs(m["min"][i] - lo[i]) > 1e-4 or abs(m["max"][i] - hi[i]) > 1e-4:
                errs.append("%s r%d: Blender mesh differs from the blueprint on axis %d" % (d["type_id"], r, i))
    return errs


def manifest_errors(mpath, catalog, prov):
    base = os.path.dirname(mpath)
    name = "%s/%s" % (os.path.basename(base), os.path.basename(mpath))
    try:
        with open(mpath, encoding="utf-8") as f:
            m = json.load(f)
    except (OSError, ValueError) as ex:
        return ["%s: cannot read (%s)" % (name, ex)]
    errs = ["%s: %s" % (name, e) for e in structure_errors(m)]
    if errs:
        return errs
    d = catalog.get(m["fixture_type_id"])
    if d is None:
        return errs + ["%s: unknown fixture type %s" % (name, m["fixture_type_id"])]
    if m["visual_id"] != d["visual_id"] and not m.get("variant"):
        errs.append("%s: visual_id %s != catalog %s" % (name, m["visual_id"], d["visual_id"]))
    if m.get("footprint") != d["footprint"]:
        errs.append("%s: footprint differs from the catalog" % name)
    if m.get("dimensions_m") != d["dimensions_m"]:
        errs.append("%s: dimensions_m differs from the catalog" % name)
    if set(m["rotations"]) != {"0", "1", "2", "3"}:
        errs.append("%s: needs all four rotations" % name)
        return errs
    for rk in ("0", "1", "2", "3"):
        r = int(rk)
        rot = m["rotations"][rk]
        cw, ch = rot["canvas_px"]
        sizes_ok = True
        for lname, fname in rot["layers"].items():
            fpath = os.path.join(base, fname)
            if not os.path.isfile(fpath):
                errs.append("%s r%d: layer %s file missing: %s" % (name, r, lname, fname))
                sizes_ok = False
                continue
            try:
                arr = load_rgba(fpath)
            except (OSError, ValueError) as ex:
                errs.append("%s r%d: layer %s unreadable (%s)" % (name, r, lname, ex))
                sizes_ok = False
                continue
            if arr.shape[1] != cw or arr.shape[0] != ch:
                errs.append("%s r%d: layer %s is %dx%d but canvas_px is %dx%d" % (name, r, lname, arr.shape[1], arr.shape[0], cw, ch))
                sizes_ok = False
        inside = lambda p: -0.5 <= p[0] <= cw + 0.5 and -0.5 <= p[1] <= ch + 0.5   # noqa: E731
        if not inside(rot["anchor_px"]):
            errs.append("%s r%d: anchor_px outside the canvas" % (name, r))
        if "sorting_anchor_px" in rot and not inside(rot["sorting_anchor_px"]):
            errs.append("%s r%d: sorting_anchor_px outside the canvas" % (name, r))
        for sid, p in rot.get("slot_anchors_px", {}).items():
            if not inside(p):
                errs.append("%s r%d: slot %s outside the canvas" % (name, r, sid))
        for p in rot.get("selection_polygon_px", []):
            if not inside(p):
                errs.append("%s r%d: selection polygon outside the canvas" % (name, r))
        if not sizes_ok or "body" not in rot["layers"]:
            continue
        union = None
        for fname in rot["layers"].values():
            ys, xs = np.nonzero(load_rgba(os.path.join(base, fname))[..., 3] > 0)
            if len(xs):
                b = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
                union = b if union is None else (min(union[0], b[0]), min(union[1], b[1]), max(union[2], b[2]), max(union[3], b[3]))
        if union is None:
            errs.append("%s r%d: all layers are fully transparent" % (name, r))
            continue
        if union[0] < PADDING_PX or union[1] < PADDING_PX or cw - union[2] < PADDING_PX or ch - union[3] < PADDING_PX:
            errs.append("%s r%d: less than %d px padding around the sprite" % (name, r, PADDING_PX))
        errs += ["%s: %s" % (name, e) for e in silhouette_errors(d, r, rot, base)]
        errs += ["%s: %s" % (name, e) for e in front_side_errors(d, r, rot)]
    return errs


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--dir", default="assets/generated/fixtures")
    p.add_argument("--catalog", default="data/fixtures/mvp_v1.json")
    args = p.parse_args(argv)
    prov_path = os.path.join(args.dir, "PROVENANCE.json")
    if not os.path.isfile(prov_path):
        print("ASSETS: %s missing (run the generator, see tools/assets/README.md)" % prov_path)
        return 1
    with open(prov_path, encoding="utf-8") as f:
        prov = json.load(f)
    with open(args.catalog, encoding="utf-8") as f:
        catalog = {d["type_id"]: d for d in json.load(f)}
    errs = calibration_errors(prov, args.dir)
    manifests = sorted(glob.glob(os.path.join(args.dir, "*", "*.visual.json")))
    if not manifests:
        errs.append("no *.visual.json manifests under %s" % args.dir)
    seen = set()
    for mpath in manifests:
        errs += manifest_errors(mpath, catalog, prov)
        seen.add(os.path.basename(os.path.dirname(mpath)))
    for t in prov.get("types", []):
        if t not in seen:
            errs.append("%s is listed in PROVENANCE.json but has no manifest" % t)
        elif t in catalog:
            errs += mesh_errors(catalog[t], prov)
    for e in errs:
        print("ASSETS:", e)
    print("asset check: %d manifest(s), %d problem(s)" % (len(manifests), len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
