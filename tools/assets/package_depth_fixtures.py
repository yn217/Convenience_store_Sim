"""Package the depth-guided fixture renders (2026-11-07) as the `depth_v1` visual variant.

Source: F:/Stable Diffusion/game-assets/depth_fixtures_all_20261107/final/<type>_y<yaw>.png (1024 px, RGBA cutouts).
Each was rendered with a Blender orthographic camera at 30 degrees elevation, framed by `bl_common.frame`: the bounding
box centre of the model at the image centre and `S` metres across the 1024 px image. The game draws iso2x_v1 sprites
at 256 px per tile diamond (181.02 px per metre across the view, 156.77 px per metre of height), so every image is
scaled by 181.02 * S / 1024 and placed so the anchor is the centre of the footprint's lo tile (FixturePresenter).

Game rotation r shows the render at yaw 90 * r: the game turns fixtures N -> E -> S -> W, and Blender's +y is the
game's north. The products are part of the picture, so the manifests say state FULL (VisualVariants.products_baked).
The user approved the variant for the game on 2026-11-14 (runtime_approved, first in visual_variants.json).

HALF and EMPTY (issue #91 stock states, 2026-11-14): depth_states_20261114/final/<type>_<state>_y<yaw>.png, the same
fixture with part or all of its goods repainted away, framed exactly like FULL. They are listed in the FULL
manifest's inventory_states ("half_r0", ...); FixturePresenter picks the state from the shelf's stock.

Run: python tools/assets/package_depth_fixtures.py [type ...]
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = Path("F:/Stable Diffusion/game-assets/depth_fixtures_all_20261107")
STATES_SRC = Path("F:/Stable Diffusion/game-assets/depth_states_20261114")
STATES = {"half": "HALF", "empty": "EMPTY"}
OUT = ROOT / "assets/generated/fixtures"
VARIANT = "depth_v1"
EL = math.radians(30)
PX_PER_M = 128 * math.sqrt(2)          # half a tile diamond (128 source px) per half diagonal (0.707 m)
HALF_W, HALF_H = 128.0, 64.0          # source px of one tile step in x (and -y) on screen
RENDER = 1024
MARGIN = 16                           # transparent px around everything (validate_manifests wants 8)
# 2026-11-14: the register's and the bakery's backs were redone, the capsule units remodelled (3 and 5 columns) and the
# dessert case's canopy kept (the daily case has the same); every fixture now has depth art.
EXCLUDE = set()


def view(yaw):
    v = np.array([math.cos(EL) / math.sqrt(2), -math.cos(EL) / math.sqrt(2), math.sin(EL)])
    a = math.radians(yaw)
    rz = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
    return rz @ v


def screen_axes(yaw):
    """Camera right and up in world coordinates (Blender's track to -Z with Y up)."""
    back = view(yaw)
    up = np.array([0.0, 0.0, 1.0]) - back * back[2]
    up /= np.linalg.norm(up)
    right = np.cross(up, back)
    return right, up


def frame(boxes):
    vs = np.array([(x, y, z) for x0, y0, z0, x1, y1, z1 in boxes for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)])
    lo, hi = vs.min(0), vs.max(0)
    tgt = (lo + hi) / 2
    ext = 0.0
    for yaw in (0, 90, 180, 270):
        r, u = screen_axes(yaw)
        c = vs - tgt
        ext = max(ext, np.abs(c @ r).max(), np.abs(c @ u).max())
    return tgt, ext * 2 * 1.14


def project(p, tgt, S, yaw):
    """Render pixel of world point p."""
    r, u = screen_axes(yaw)
    c = np.asarray(p, float) - tgt
    return np.array([(c @ r / S + 0.5) * RENDER, (0.5 - c @ u / S) * RENDER])


def shadow(canvas, anchor, w, h):
    """A soft footprint shadow on the floor, a little larger than the footprint."""
    img = Image.new("L", canvas, 0)
    d = ImageDraw.Draw(img)
    ax, ay = anchor
    pad = 0.12

    def pt(gx, gy):
        return (ax + (gx - gy) * HALF_W, ay + (gx + gy) * HALF_H)

    x0, y0, x1, y1 = -0.5 - pad, -0.5 - pad, w - 0.5 + pad, h - 0.5 + pad
    d.polygon([pt(x0, y0), pt(x1, y0), pt(x1, y1), pt(x0, y1)], fill=110)
    img = img.filter(ImageFilter.GaussianBlur(10))
    out = Image.new("RGBA", canvas, (20, 14, 10, 0))
    out.putalpha(img)
    return out


def package(type_id, catalog, boxes, state=""):
    fx = catalog[type_id]
    base_path = OUT / type_id / f"{type_id}_a.visual.json"
    base = json.loads(base_path.read_text(encoding="utf-8"))
    tgt, S = frame(boxes[type_id])
    k = PX_PER_M * S / RENDER
    manifest = {k2: v for k2, v in base.items() if k2 != "rotations"}
    # state FULL = products baked into the picture (VisualVariants.products_baked); provenance is in docs/ASSET_CREDITS.md.
    vid = f"{type_id}_{VARIANT}" + (f"_{state}" if state else "")
    manifest.update({"visual_id": vid, "variant": VARIANT, "state": STATES.get(state, "FULL"), "runtime_approved": True})   # the user's decision 2026-11-14
    manifest["rotations"] = {}
    report = {}
    for r in range(4):
        yaw = 90 * r
        src = Image.open((STATES_SRC / "final" / f"{type_id}_{state}_y{yaw}.png") if state else (SRC / "final" / f"{type_id}_y{yaw}.png")).convert("RGBA")
        # A stock state is cut with the FULL picture's box, so all three share canvas and anchor.
        bbox = Image.open(SRC / "final" / f"{type_id}_y{yaw}.png").getbbox() if state else src.getbbox()
        crop = src.crop(bbox)
        size = (max(1, round(crop.width * k)), max(1, round(crop.height * k)))
        body = crop.resize(size, Image.Resampling.LANCZOS)
        w, h = (fx["w"], fx["h"]) if r % 2 == 0 else (fx["h"], fx["w"])
        # The model is centred on its footprint at the origin; the anchor is the lo tile's centre.
        origin = (project((0, 0, 0), tgt, S, yaw) - np.array(bbox[:2])) * k
        anchor = origin - np.array([(w - 1) / 2 * HALF_W - (h - 1) / 2 * HALF_W, (w - 1) / 2 * HALF_H + (h - 1) / 2 * HALF_H])
        # Room for the body and its floor shadow (the footprint plus a blurred margin), with MARGIN px all round.
        corners = [anchor + np.array([(gx - gy) * HALF_W, (gx + gy) * HALF_H]) for gx in (-0.8, w - 0.2) for gy in (-0.8, h - 0.2)]
        lo = np.minimum(np.min(corners, 0), [0, 0]) - MARGIN
        hi = np.maximum(np.max(corners, 0), size) + MARGIN
        canvas = (int(math.ceil(hi[0] - lo[0])), int(math.ceil(hi[1] - lo[1])))
        off = (int(round(-lo[0])), int(round(-lo[1])))
        anchor = anchor + off
        out = Image.new("RGBA", canvas)
        out.alpha_composite(body, off)
        name = f"{vid}_{r}"
        out.save(OUT / type_id / f"{name}_body.png")
        shadow(canvas, anchor, w, h).save(OUT / type_id / f"{name}_shadow.png")
        b = base["rotations"][str(r)]
        shift = anchor - np.array(b["anchor_px"])
        rot = {"canvas_px": list(canvas), "anchor_px": [round(float(anchor[0]), 2), round(float(anchor[1]), 2)],
               "layers": {"body": f"{name}_body.png", "shadow": f"{name}_shadow.png"},
               "sorting_anchor_px": [round(float(anchor[0]), 2), round(float(anchor[1]), 2)]}
        if "slot_anchors_px" in b:
            rot["slot_anchors_px"] = {s: [round(p[0] + shift[0], 2), round(p[1] + shift[1], 2)] for s, p in b["slot_anchors_px"].items()}
        if "selection_polygon_px" in b:
            rot["selection_polygon_px"] = [[round(p[0] + shift[0], 2), round(p[1] + shift[1], 2)] for p in b["selection_polygon_px"]]
        manifest["rotations"][str(r)] = rot
        report[r] = {"scale": round(k, 4), "canvas": canvas}
    if state:
        return manifest["rotations"]   # the caller files them under the FULL manifest's inventory_states
    (OUT / type_id / f"{vid}.visual.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    catalog = {}
    for t in json.loads((ROOT / "data/fixtures/mvp_v1.json").read_text(encoding="utf-8")):
        catalog[t["type_id"]] = t["footprint"]
    boxes = json.loads((SRC / "boxes.json").read_text(encoding="utf-8"))
    wanted = sys.argv[1:] or [t for t in catalog if t in boxes and t not in EXCLUDE]
    for t in wanted:
        if not (OUT / t / f"{t}_a.visual.json").exists():
            print("skip (no base manifest)", t)
            continue
        print(t, package(t, catalog, boxes)[0])
        # HALF / EMPTY go into the FULL manifest as inventory_states {"<state>_r<rotation>": rotation record}: the
        # format FixtureSprites reads on the Codex branch too (issue #168), not manifests of their own.
        states = {}
        for state in STATES:
            if all((STATES_SRC / "final" / f"{t}_{state}_y{y}.png").exists() for y in (0, 90, 180, 270)):
                for r, rot in package(t, catalog, boxes, state).items():
                    states[f"{state}_r{r}"] = dict(rot, state=STATES[state], rotation=int(r))
                print("  +", state)
        if states:
            path = OUT / t / f"{t}_{VARIANT}.visual.json"
            manifest = json.loads(path.read_text(encoding="utf-8"))
            manifest["inventory_states"] = states
            path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
