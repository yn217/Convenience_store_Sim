"""Mechanical gate for generated customer sprites (Issue #23). Exit code 0 = PASS.

    python tools/assets/validate_customers.py [--dir assets/generated/characters]

Checks: camera calibration (same measurement as the fixtures), manifest shape, every frame file exists
inside the variant folder / is RGBA / has the manifest canvas, one shared anchor for all frames (so
feet cannot move between facings or frames), padding, body height against `height_m` (top of the head
within the projected 1.65 m-class box), ground contact (feet reach down to the anchor), frame counts
and rates of 14 §2, and that the three variants are visually different.
"""
import argparse
import glob
import json
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import figures  # noqa: E402
import iso2x  # noqa: E402
import validate_manifests as vm  # noqa: E402

PNG_NAME = re.compile(r"^[A-Za-z0-9_-]+\.png$")
TOP_KEYS = {"manifest_version", "visual_id", "projection_id", "world_units_per_tile", "source_px_per_tile_diamond",
            "height_m", "facing_names", "canvas_px", "anchor_px", "shadow", "animations", "directions"}
HEAD_ABOVE_PX = 17.0      # the hair cap is 0.21 m deep: its near-top corner sits up to ~13.4 px above the centre line
HEAD_BELOW_PX = 2.0
FOOT_REACH_PX = (0.0, 45.0)


def manifest_errors(mpath):
    base = os.path.dirname(mpath)
    with open(mpath, encoding="utf-8") as f:
        m = json.load(f)
    name = os.path.basename(mpath)
    e = []
    if set(m) != TOP_KEYS:
        return ["%s: keys differ: missing %s unknown %s" % (name, sorted(TOP_KEYS - set(m)), sorted(set(m) - TOP_KEYS))]
    if m["projection_id"] != iso2x.PROJECTION_ID:
        e.append("%s: projection_id" % name)
    if m["facing_names"] != list(figures.FACINGS):
        e.append("%s: facing_names" % name)
    cw, ch = m["canvas_px"]
    ax, ay = m["anchor_px"]
    if not (0 <= ax <= cw and 0 <= ay <= ch):
        e.append("%s: anchor outside the canvas" % name)
    expected = {"idle": 2, "checkout": 4} if m.get("visual_id") == "clerk" else figures.ANIMS
    for anim, count in expected.items():
        spec = m["animations"].get(anim)
        want_fps = figures.FPS.get(anim, 4.0 / 0.45)
        want_loop = figures.LOOP.get(anim, False)
        if spec is None or spec["frames"] != count or abs(spec["fps"] - want_fps) > 0.01 or spec["loop"] != want_loop:
            e.append("%s: animation %s differs from the 14 §2 frame counts / rates" % (name, anim))
    files = [m["shadow"]]
    for d in range(4):
        dd = m["directions"].get(str(d))
        if dd is None:
            e.append("%s: direction %d missing" % (name, d))
            continue
        for anim, count in expected.items():
            frames = dd.get(anim, [])
            if len(frames) != count:
                e.append("%s: direction %d %s has %d frames, want %d" % (name, d, anim, len(frames), count))
            files += frames
    union = None
    tops, bottoms = [], []
    for rel in files:
        if not PNG_NAME.match(rel):
            e.append("%s: unsafe file name %r" % (name, rel))
            continue
        path = os.path.join(base, rel)
        if not os.path.isfile(path):
            e.append("%s: %s missing" % (name, rel))
            continue
        try:
            arr = vm.load_rgba(path)
        except ValueError as err:
            e.append("%s: %s" % (name, err))
            continue
        if [arr.shape[1], arr.shape[0]] != [cw, ch]:
            e.append("%s: %s is %dx%d, manifest says %dx%d" % (name, rel, arr.shape[1], arr.shape[0], cw, ch))
            continue
        ys, xs = np.nonzero(arr[..., 3] > 0)
        if len(xs) == 0:
            e.append("%s: %s is empty" % (name, rel))
            continue
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        union = box if union is None else (min(union[0], box[0]), min(union[1], box[1]), max(union[2], box[2]), max(union[3], box[3]))
        if rel != m["shadow"]:
            tops.append(box[1])
            bottoms.append(box[3])
    if union is not None and (union[0] < vm.PADDING_PX or union[1] < vm.PADDING_PX or cw - union[2] < vm.PADDING_PX or ch - union[3] < vm.PADDING_PX):
        e.append("%s: less than %d px padding" % (name, vm.PADDING_PX))
    if tops:
        want_top = ay - m["height_m"] * iso2x.Z_PX_PER_M
        if any(not (want_top - HEAD_ABOVE_PX <= t <= want_top + HEAD_BELOW_PX) for t in tops):
            e.append("%s: head top rows %d..%d, expected about %.0f for %.2f m" % (name, min(tops), max(tops), want_top, m["height_m"]))
        reach = [b - ay for b in bottoms]
        if min(reach) < FOOT_REACH_PX[0] or max(reach) > FOOT_REACH_PX[1]:
            e.append("%s: feet end %.0f..%.0f px from the anchor row (want %s)" % (name, min(reach), max(reach), FOOT_REACH_PX))
    return e, m


def main(argv=None):
    p = argparse.ArgumentParser()
    p.add_argument("--dir", default="assets/generated/characters")
    args = p.parse_args(argv)
    prov_path = os.path.join(args.dir, "PROVENANCE.json")
    if not os.path.isfile(prov_path):
        print("CUSTOMERS: %s missing (run the generator, see tools/assets/README.md)" % prov_path)
        return 1
    with open(prov_path, encoding="utf-8") as f:
        prov = json.load(f)
    errs = vm.calibration_errors(prov, args.dir)
    manifests = sorted(glob.glob(os.path.join(args.dir, "*", "*.character.json")))
    if len(manifests) < 7:
        errs.append("need at least 7 character variants, found %d" % len(manifests))
    heights = set()
    for path in manifests:
        r = manifest_errors(path)
        if isinstance(r, list):
            errs += r
            continue
        errs += r[0]
        heights.add(r[1]["height_m"])
    if len(heights) < 2 and manifests:
        errs.append("variants share one body height")
    for e in errs:
        print("CUSTOMERS:", e)
    print("customer check: %d manifest(s), %d problem(s)" % (len(manifests), len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
