"""Idol Gaussian Splat PLY -> game fixture layers + manifest (iso2x_v1, any footprint), the splat counterpart of
tools/assets/pixal3d/render_fixture.py + crop_fixture.py.

    <idol venv python> -I tools/assets/idol/render_fixture_splat.py --ply reference.ply --type coffee_machine \
        --front_yaw 120 [--out assets/generated/fixtures/coffee_machine] [--preview sheet.png]

--front_yaw: the azimuth of the model's front in the Idol frame (degrees, the camera.json convention: direction
(sin yaw, cos yaw)); --preview writes an 8-view sheet (0, 45, ... 315) to pick it by eye.

The model is cleaned (faint and stray splats), turned so its front faces game S, fitted into the fixture's body box
(data/fixtures/mvp_v1.json dimensions_m: one horizontal scale, the vertical one held within 15 % of it so nothing is
squashed), cut to the box, then turned to its access edge and drawn for the four rotations. The anchor is the centre
of the fixture's first tile (lo), the footprint runs along +x / +y with w and h swapped on rotations 1 and 3, as
FixturePresenter and StoreGrid.footprint_cells place it.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
import torch
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import splat_render as S  # noqa: E402

HALF_W, HALF_H, Z_PX = 128.0, 64.0, 156.77
SS = 2                      # supersampling
PAD = 10
SHADOW_GROW_M = 0.06
SHADOW_ALPHA = 70
STRETCH = 1.3
EDGES = ["N", "E", "S", "W"]
FIXTURES = "data/fixtures/mvp_v1.json"


def iso(x, y, z=0.0):
    return HALF_W * (x - y), HALF_H * (x + y) - Z_PX * z


def rotz(deg):
    a = math.radians(deg)
    return torch.tensor([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]], dtype=torch.float32, device=S.DEV)


def clean(g, min_alpha=0.04, clip=True):
    g = S.select(g, g["alpha"] > min_alpha)
    if not clip:   # #238 ablation: keep the stray splats outside the 0.5-99.5 % box
        return g
    p = g["xyz"]
    lo = torch.quantile(p[::7], 0.005, dim=0)
    hi = torch.quantile(p[::7], 0.995, dim=0)
    pad = 0.04 * (hi - lo).max()
    keep = ((p > lo - pad) & (p < hi + pad)).all(1)
    return S.select(g, keep)


def preview(g, path):
    tiles = []
    for k in range(8):
        J, v = S.orbit(math.radians(45 * k), math.radians(12), 380)
        im = Image.fromarray(S.rasterize(g, J, v, (200, 210), (400, 420)), "RGBA")
        bg = Image.new("RGBA", im.size, "white")
        bg.alpha_composite(im)
        ImageDraw.Draw(bg).text((8, 6), "yaw %d" % (45 * k), fill="red")
        tiles.append(bg)
    sheet = Image.new("RGB", (400 * 4, 420 * 2), "white")
    for k, t in enumerate(tiles):
        sheet.paste(t.convert("RGB"), ((k % 4) * 400, (k // 4) * 420))
    sheet.save(path)


def align_yaw(g, front_yaw, spread=25.0):
    """The yaw within +-spread degrees of front_yaw whose robust plan box is smallest: a boxy model (a room, a
    counter) then sits square to its footprint instead of as a parallelogram."""
    p = g["xyz"][::9, :2]
    best = (float("inf"), front_yaw)
    for d in np.arange(-spread, spread + 0.5, 0.5):
        a = math.radians(front_yaw + d - 180.0)
        r = torch.tensor([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]], device=S.DEV)
        q = p @ r.T
        ext = torch.quantile(q, 0.99, dim=0) - torch.quantile(q, 0.01, dim=0)
        area = float(ext[0] * ext[1])
        if area < best[0]:
            best = (area, front_yaw + float(d))
    return best[1]


def deskew(g):
    """Idol can rebuild a room as a parallelogram. Shear x by y (and y by x) by the amounts that make the robust plan
    box smallest, so the walls run square again. Returns (g, [kx, ky])."""
    p = g["xyz"][::9]
    ks = []
    for i, j in ((0, 1), (1, 0)):
        best = (float("inf"), 0.0)
        for k in np.arange(-0.6, 0.61, 0.01):
            v = p[:, i] - float(k) * p[:, j]
            e = float(torch.quantile(v, 0.99) - torch.quantile(v, 0.01))
            if e < best[0]:
                best = (e, float(k))
        m = torch.eye(3, device=S.DEV)
        m[i, j] = -best[1]
        g = S.transform(g, m, torch.zeros(3, device=S.DEV))
        p = p @ m.T
        ks.append(round(best[1], 2))
    return g, ks


def fit(g, front_yaw, across, deep, height, stretch=STRETCH, skew=False, cut=True, vertical_slack=0.15):
    """Front to -y (object frame), centred, scaled into across x deep x height, cut to it; then mirrored into the
    game frame (left-handed: gy = -oy) so the front faces game +y = S."""
    g = S.transform(g, rotz(front_yaw - 180.0), torch.zeros(3, device=S.DEV))   # azimuth yaw -> 180 (= -y)
    shear = None
    if skew:
        g, shear = deskew(g)
    p = g["xyz"]
    lo = torch.quantile(p[::5], 0.005, dim=0)
    hi = torch.quantile(p[::5], 0.995, dim=0)
    ext = (hi - lo).tolist()
    s_h = min(across / ext[0], deep / ext[1])
    # each horizontal axis may stretch up to STRETCH times the other, so the model fills its footprint (it stands on
    # the near corner) without looking squashed
    s_x = min(across / ext[0], stretch * s_h)
    s_y = min(deep / ext[1], stretch * s_h)
    s_m = math.sqrt(s_x * s_y)
    s_v = min(max(height / ext[2], (1 - vertical_slack) * s_m), (1 + vertical_slack) * s_m)
    centre = torch.tensor([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]], device=S.DEV)
    m = torch.diag(torch.tensor([s_x, -s_y, s_v], device=S.DEV))
    g = S.transform(g, m, -(m @ centre))
    q = g["xyz"]
    eps = -0.01   # cut a little inside the box: the splats' soft edges stay within the envelope
    keep = (q[:, 0].abs() <= across / 2 + eps) & (q[:, 1].abs() <= deep / 2 + eps) & (q[:, 2] >= -0.01) & (q[:, 2] <= height + 0.01)
    info = {"robust_extent_before_scale": [round(e, 4) for e in ext], "scale_x": round(s_x, 4), "scale_y": round(s_y, 4),
            "scale_vertical": round(s_v, 4), "cut_splats": int((~keep).sum()), "shear": shear}
    return (S.select(g, keep) if cut else g), info


def turn_matrix(quarter):
    """Clockwise quarter turns on the map (N -> E -> S -> W): (x, y) -> (-y, x)."""
    m = torch.tensor([[0, -1, 0], [1, 0, 0], [0, 0, 1]], dtype=torch.float32, device=S.DEV)
    return torch.linalg.matrix_power(m, quarter % 4)


def layer_image(img, size):
    """Supersampled straight-alpha RGBA -> `size`, downscaled premultiplied so the edges keep their colour."""
    f = img.astype(np.float32)
    f[..., :3] *= f[..., 3:4] / 255.0
    small = np.stack([np.asarray(Image.fromarray(f[..., c]).resize(size, Image.BOX)) for c in range(4)], -1)
    al = small[..., 3:4]
    rgb = np.where(al > 0, small[..., :3] * 255.0 / np.maximum(al, 1), 0)
    return Image.fromarray(np.concatenate([rgb, al], -1).clip(0, 255).astype(np.uint8), "RGBA")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--ply", required=True)
    p.add_argument("--type", required=True)
    p.add_argument("--front_yaw", type=float, default=0.0)
    p.add_argument("--out")
    p.add_argument("--visual_id")
    p.add_argument("--preview")
    p.add_argument("--slots", type=float, nargs=5, metavar=("COLS", "ROWS", "Z", "X_HALF", "Y_HALF"),
                   help="product cells cell0.. on a grid over the body (front-S frame, metres), item bottoms at Z")
    p.add_argument("--stretch", type=float, default=STRETCH, help="how far one horizontal axis may stretch past the other")
    p.add_argument("--deskew", action="store_true", help="shear a parallelogram model back square (rooms)")
    p.add_argument("--align", action="store_true", help="refine --front_yaw by the smallest plan box (boxy models)")
    p.add_argument("--drop_above", type=float, help="drop the splats above this height (an opaque-looking glass lid)")
    p.add_argument("--cutaway", type=float, nargs=2, metavar=("Z", "BAND"),
                   help="rooms: drop the splats above Z within BAND tiles of the two edges nearest the viewer, so the near walls are cut low")
    p.add_argument("--glass_alpha", type=float, default=1.0, help="opacity of the glass_front layer")
    p.add_argument("--glass_above", type=float,
                   help="splats above this height on the viewer's half go to a glass_front layer drawn over the products")
    a = p.parse_args()
    g = clean(S.load(a.ply))
    if a.preview:
        preview(g, a.preview)
        if not a.out:
            return
    d = next(f for f in json.load(open(FIXTURES, encoding="utf-8")) if f["type_id"] == a.type)
    fw, fh = int(d["footprint"]["w"]), int(d["footprint"]["h"])
    dims = d["dimensions_m"]
    k = (EDGES.index(d["access_edges"][0]) - EDGES.index("S")) % 4    # quarter turns from S to the access edge
    across, deep = (dims["depth"], dims["width"]) if k % 2 else (dims["width"], dims["depth"])
    if a.align:
        a.front_yaw = align_yaw(g, a.front_yaw)
    body, info = fit(g, a.front_yaw, across, deep, dims["height"], a.stretch, a.deskew)
    if a.drop_above is not None:
        body = S.select(body, body["xyz"][:, 2] <= a.drop_above)
    info.update({"cutaway": a.cutaway, "slots": a.slots, "glass_above": a.glass_above, "glass_alpha": a.glass_alpha, "drop_above": a.drop_above, "ply": a.ply, "type": a.type, "front_yaw": a.front_yaw, "access_edge": d["access_edges"][0]})
    c30 = math.cos(math.radians(30)) / math.sqrt(2)
    view = torch.tensor([c30, c30, 0.5], device=S.DEV)      # towards the camera: 30 deg up, from game (+1, +1)
    J = torch.tensor([[HALF_W, -HALF_W, 0.0], [HALF_H, HALF_H, -Z_PX]], device=S.DEV)
    vid = a.visual_id or a.type + "_a"
    os.makedirs(a.out, exist_ok=True)
    rotations = {}
    for r in range(4):
        wr, hr = (fh, fw) if r % 2 else (fw, fh)
        cx, cy = (wr - 1) / 2, (hr - 1) / 2                      # body box centre, tile units from the lo tile centre
        tm = turn_matrix(k + r)
        shift = torch.tensor([cx, cy, 0.0], device=S.DEV)
        gr = S.transform(body, tm, shift)
        corners = [(-0.5, -0.5), (wr - 0.5, -0.5), (wr - 0.5, hr - 0.5), (-0.5, hr - 0.5)]
        top = max(dims["height"], 0.1)
        xs = [iso(x, y, z)[0] for x, y in corners for z in (0, top)]
        ys = [iso(x, y, z)[1] for x, y in corners for z in (0, top)]
        x0, y0 = math.floor(min(xs)) - PAD - 40, math.floor(min(ys)) - PAD - 40
        W, H = math.ceil(max(xs)) - x0 + PAD + 40, math.ceil(max(ys)) - y0 + PAD + 40
        ox, oy = -x0, -y0
        if a.cutaway:
            q = gr["xyz"]
            z, band = a.cutaway
            near = (q[:, 2] > z) & ((q[:, 0] > wr - 0.5 - band) | (q[:, 1] > hr - 0.5 - band))
            gr = S.select(gr, ~near)
        glass = None
        if a.glass_above is not None:
            q = gr["xyz"]
            near = (q[:, 2] > a.glass_above) & ((q[:, 0] - cx) + (q[:, 1] - cy) > 0)
            glass = layer_image(S.rasterize(S.select(gr, near), J * SS, view, (ox * SS, oy * SS), (W * SS, H * SS)), (W, H))
            glass.putalpha(glass.getchannel("A").point(lambda v: round(v * a.glass_alpha)))
            gr = S.select(gr, ~near)
        body_img = layer_image(S.rasterize(gr, J * SS, view, (ox * SS, oy * SS), (W * SS, H * SS)), (W, H))
        gx = SHADOW_GROW_M
        sh = Image.new("L", (W, H), 0)
        pts = [(ox + iso(x, y)[0], oy + iso(x, y)[1]) for x, y in
               ((-0.5 - gx, -0.5 - gx), (wr - 0.5 + gx, -0.5 - gx), (wr - 0.5 + gx, hr - 0.5 + gx), (-0.5 - gx, hr - 0.5 + gx))]
        ImageDraw.Draw(sh).polygon(pts, fill=SHADOW_ALPHA)
        sh = sh.filter(ImageFilter.GaussianBlur(6))
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        shadow.putalpha(sh)
        both = np.maximum(np.asarray(body_img)[..., 3], np.asarray(sh))
        yy, xx = np.nonzero(both > 0)
        bx0, by0 = int(max(0, xx.min() - PAD)), int(max(0, yy.min() - PAD))
        bx1, by1 = int(min(W, xx.max() + 1 + PAD)), int(min(H, yy.max() + 1 + PAD))
        names = {"body": "%s_%d_body.png" % (a.type, r), "shadow": "%s_%d_shadow.png" % (a.type, r)}
        body_img.crop((bx0, by0, bx1, by1)).save(os.path.join(a.out, names["body"]))
        if glass is not None:
            names["glass_front"] = "%s_%d_glass_front.png" % (a.type, r)
            glass.crop((bx0, by0, bx1, by1)).save(os.path.join(a.out, names["glass_front"]))
        shadow.crop((bx0, by0, bx1, by1)).save(os.path.join(a.out, names["shadow"]))
        ax, ay = round(ox - bx0, 2), round(oy - by0, 2)
        poly = [[round(ax + iso(x, y)[0], 2), round(ay + iso(x, y)[1], 2)] for x, y in corners]
        slots = {}
        if a.slots:
            cols, rows, z, xh, yh = int(a.slots[0]), int(a.slots[1]), a.slots[2], a.slots[3], a.slots[4]
            for row in range(rows):
                for col in range(cols):
                    pt = torch.tensor([-xh + (col + 0.5) * 2 * xh / cols, -yh + (row + 0.5) * 2 * yh / rows, z], device=S.DEV)
                    x, y, zz = (tm @ pt + shift).tolist()
                    u, v = iso(x, y, zz)
                    slots["cell%d_item0" % (row * cols + col)] = [round(ax + u, 2), round(ay + v, 2)]
        rotations[str(r)] = {"canvas_px": [bx1 - bx0, by1 - by0], "anchor_px": [ax, ay],
                             "layers": names, "slot_anchors_px": slots, "selection_polygon_px": poly, "sorting_anchor_px": [ax, ay]}
    manifest = {"manifest_version": 1, "visual_id": vid, "fixture_type_id": a.type, "projection_id": "iso2x_v1",
                "world_units_per_tile": 1, "source_px_per_tile_diamond": [256, 128], "footprint": {"w": fw, "h": fh},
                "dimensions_m": dims, "rotations": rotations}
    with open(os.path.join(a.out, vid + ".visual.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(a.out, "render_info.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print(json.dumps({"info": info, "canvas": {r: v["canvas_px"] for r, v in rotations.items()}}))


if __name__ == "__main__":
    main()
