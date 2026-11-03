"""#238: the same Idol PLY through several splat rasterizers and post-processing settings, with the same camera,
canvas and anchor, so a visible defect can be put on (A) the PLY, (B) the rasterizer, (C) clean / fit / cut or (D)
Godot. Writes every render as a PNG, contact sheets, and records.json (PLY facts and SHA, settings, PNG SHA,
coverage, difference from the baseline, time and VRAM). Nothing under assets/ is written or replaced.

    F:/AI_Tools/gsplat-venv/Scripts/python.exe -I tools/assets/idol/splat_compare.py crane_game [...] \
        --out F:/Cordex_OpenAI/_idol238 [--stage raw|game|all] [--src <Idol source folder>]

Stages:
  raw   the PLY as Idol wrote it (no clean, fit, cut): turned so the front faces S and scaled evenly (a similarity,
        so no splat changes shape), in the game's iso2x_v1 view for the four quarter turns, by every backend.
  game  the fixture pipeline of render_fixture_splat.py (fixtures.json settings) for the four rotations on one
        fixed canvas per rotation; "baseline" is the pipeline as it is, each other condition changes one thing.
        The baseline is checked pixel for pixel against the committed assets/generated/fixtures/<type> PNGs.
"""
import argparse
import hashlib
import io
import json
import math
import os
import sys
import time

import numpy as np
import torch
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ply_info  # noqa: E402
import render_fixture_splat as R  # noqa: E402
import splat_backends as B  # noqa: E402
import splat_render as S  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC = "F:/Cordex_OpenAI/ゲーム製作_コンビニ経営/assets/source/idol"
RAW_PX = 300.0           # px per unit of the robust plan size in the raw views
RAW_SIZE = (720, 720)
GREY = (128, 128, 128)

# one change each from the baseline (current rasterizer, fixtures.json settings)
CONDITIONS = {
    "baseline": {},
    "gsplat_classic": {"backend": "gsplat_classic"},
    "gsplat_aa": {"backend": "gsplat_aa"},
    "radius_256": {"backend": "current_r256"},
    "no_dilation": {"backend": "current_nodil"},
    "min_alpha_0": {"min_alpha": 0.0},
    "no_outlier_clip": {"clip": False},
    "no_box_cut": {"cut": False},
    "isotropic_fit": {"stretch": 1.0, "vertical_slack": 0.0},
    "no_align": {"align": False},
    "no_deskew": {"deskew": False},
    "no_cutaway": {"cutaway": None},
    "no_drop_above": {"drop_above": None},
    "no_glass_split": {"glass_above": None},
    "no_supersample": {"ss": 1},
}


def fixture_options(cfg: dict) -> dict:
    """fixtures.json args -> the render_fixture_splat.py options this harness varies."""
    p = argparse.ArgumentParser()
    p.add_argument("--slots", type=float, nargs=5)
    p.add_argument("--stretch", type=float, default=R.STRETCH)
    p.add_argument("--deskew", action="store_true")
    p.add_argument("--align", action="store_true")
    p.add_argument("--drop_above", type=float)
    p.add_argument("--cutaway", type=float, nargs=2)
    p.add_argument("--glass_alpha", type=float, default=1.0)
    p.add_argument("--glass_above", type=float)
    a = vars(p.parse_args(cfg.get("args", [])))
    a.update({"front_yaw": float(cfg["front_yaw"]), "min_alpha": 0.04, "clip": True, "cut": True, "vertical_slack": 0.15,
              "backend": "current", "ss": R.SS})
    return a


def applicable(name: str, opts: dict) -> bool:
    """A condition that would change nothing for this fixture (no glass split to turn off, ...) is skipped."""
    ch = CONDITIONS[name]
    return all(opts.get(k) != v for k, v in ch.items()) or name == "baseline"


def png_bytes(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()


def save_png(img: Image.Image, path: str) -> str:
    data = png_bytes(img)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return hashlib.sha256(data).hexdigest()


def timed(fn, *args):
    if torch.cuda.is_available():
        torch.cuda.synchronize()
        torch.cuda.reset_peak_memory_stats()
    t = time.perf_counter()
    out = fn(*args)
    if torch.cuda.is_available():
        torch.cuda.synchronize()
    ms = (time.perf_counter() - t) * 1000
    mb = torch.cuda.max_memory_allocated() / 2 ** 20 if torch.cuda.is_available() else 0.0
    return out, round(ms, 1), round(mb, 1)


def metrics(img: np.ndarray, ref: np.ndarray = None) -> dict:
    """coverage: pixels with alpha >= 0.5; detail: the mean gradient of the premultiplied luminance where alpha >= 0.5
    (higher = sharper or noisier: read it with the picture); diff_*: from `ref` (same canvas)."""
    f = B.straight_to_premult(img)
    lum = f[..., :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    mask = f[..., 3] >= 0.5
    gy, gx = np.gradient(lum)
    out = {"coverage_px": int(mask.sum()), "alpha_sum": round(float(f[..., 3].sum()), 1),
           "detail": round(float(np.hypot(gx, gy)[mask].mean()) if mask.any() else 0.0, 5)}
    if ref is not None:
        r = B.straight_to_premult(ref)
        d = np.abs(f - r).max(-1)
        out.update({"diff_mean": round(float(d.mean()), 5), "diff_px_over_8": int((d > 8 / 255).sum()),
                    "diff_alpha_px_over_8": int((np.abs(f[..., 3] - r[..., 3]) > 8 / 255).sum())})
    return out


def over(img: np.ndarray, bg) -> Image.Image:
    base = Image.new("RGBA", (img.shape[1], img.shape[0]), tuple(bg) + (255,))
    base.alpha_composite(Image.fromarray(img, "RGBA"))
    return base.convert("RGB")


# ---------------------------------------------------------------- raw stage

def raw_scene(g: dict, front_yaw: float) -> dict:
    """Front to game S (as fit() turns it) and an even scale so the robust plan size is 1 unit; no splat dropped."""
    g = S.transform(g, R.rotz(front_yaw - 180.0), torch.zeros(3, device=S.DEV))
    p = g["xyz"]
    lo = torch.quantile(p[::5], 0.005, dim=0)
    hi = torch.quantile(p[::5], 0.995, dim=0)
    s = 1.0 / float(max(hi[0] - lo[0], hi[1] - lo[1]))
    centre = torch.tensor([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]], device=S.DEV)
    m = torch.diag(torch.tensor([s, -s, s], device=S.DEV))      # the same mirror into the game frame as fit()
    return S.transform(g, m, -(m @ centre))


def raw_camera():
    c30 = math.cos(math.radians(30)) / math.sqrt(2)
    view = torch.tensor([c30, c30, 0.5], device=S.DEV)
    J = torch.tensor([[R.HALF_W, -R.HALF_W, 0.0], [R.HALF_H, R.HALF_H, -R.Z_PX]], device=S.DEV) * (RAW_PX / (2 * R.HALF_W))
    return J, view, (RAW_SIZE[0] / 2, RAW_SIZE[1] * 0.68)


def run_raw(g_raw: dict, opts: dict, backends: list, out: str) -> dict:
    scene = raw_scene(g_raw, opts["front_yaw"])
    J, view, origin = raw_camera()
    rec = {}
    for r in range(4):
        gr = S.transform(scene, R.turn_matrix(r), torch.zeros(3, device=S.DEV))
        ref = None
        for name in backends:
            img, ms, mb = timed(B.BACKENDS[name], gr, J, view, origin, RAW_SIZE)
            sha = save_png(Image.fromarray(img, "RGBA"), os.path.join(out, "raw", "%s_r%d.png" % (name, r)))
            ref = img if ref is None else ref
            rec["%s_r%d" % (name, r)] = {"backend": name, "rotation": r, "png_sha256": sha, "ms": ms, "peak_vram_mb": mb,
                                         **metrics(img, None if name == backends[0] else ref)}
    return rec


# ---------------------------------------------------------------- game stage

def fixture_def(type_id: str) -> dict:
    with open(os.path.join(ROOT, R.FIXTURES), encoding="utf-8") as f:
        return next(d for d in json.load(f) if d["type_id"] == type_id)


def game_render(g_raw: dict, d: dict, o: dict, rasterize) -> tuple:
    """render_fixture_splat.main's body / glass_front layers for the four rotations, on the uncropped canvas.
    Returns ([{rotation, origin, size, body, glass}], info)."""
    g = R.clean(g_raw, o["min_alpha"], o["clip"])
    fw, fh = int(d["footprint"]["w"]), int(d["footprint"]["h"])
    dims = d["dimensions_m"]
    k = (R.EDGES.index(d["access_edges"][0]) - R.EDGES.index("S")) % 4
    across, deep = (dims["depth"], dims["width"]) if k % 2 else (dims["width"], dims["depth"])
    yaw = R.align_yaw(g, o["front_yaw"]) if o["align"] else o["front_yaw"]
    body, info = R.fit(g, yaw, across, deep, dims["height"], o["stretch"], o["deskew"], o["cut"], o["vertical_slack"])
    if o["drop_above"] is not None:
        body = S.select(body, body["xyz"][:, 2] <= o["drop_above"])
    info.update({"front_yaw_used": yaw, "splats_raw": int(g_raw["xyz"].shape[0]), "splats_after_clean": int(g["xyz"].shape[0]),
                 "splats_body": int(body["xyz"].shape[0])})
    c30 = math.cos(math.radians(30)) / math.sqrt(2)
    view = torch.tensor([c30, c30, 0.5], device=S.DEV)
    J = torch.tensor([[R.HALF_W, -R.HALF_W, 0.0], [R.HALF_H, R.HALF_H, -R.Z_PX]], device=S.DEV)
    ss = o["ss"]
    views = []
    for r in range(4):
        wr, hr = (fh, fw) if r % 2 else (fw, fh)
        cx, cy = (wr - 1) / 2, (hr - 1) / 2
        tm = R.turn_matrix(k + r)
        gr = S.transform(body, tm, torch.tensor([cx, cy, 0.0], device=S.DEV))
        corners = [(-0.5, -0.5), (wr - 0.5, -0.5), (wr - 0.5, hr - 0.5), (-0.5, hr - 0.5)]
        top = max(dims["height"], 0.1)
        xs = [R.iso(x, y, z)[0] for x, y in corners for z in (0, top)]
        ys = [R.iso(x, y, z)[1] for x, y in corners for z in (0, top)]
        x0, y0 = math.floor(min(xs)) - R.PAD - 40, math.floor(min(ys)) - R.PAD - 40
        W, H = math.ceil(max(xs)) - x0 + R.PAD + 40, math.ceil(max(ys)) - y0 + R.PAD + 40
        ox, oy = -x0, -y0
        if o["cutaway"]:
            q = gr["xyz"]
            z, band = o["cutaway"]
            gr = S.select(gr, ~((q[:, 2] > z) & ((q[:, 0] > wr - 0.5 - band) | (q[:, 1] > hr - 0.5 - band))))
        draw = lambda part: rasterize(part, J * ss, view, (ox * ss, oy * ss), (W * ss, H * ss))
        glass = None
        ms_total, mb_peak = 0.0, 0.0
        if o["glass_above"] is not None:
            q = gr["xyz"]
            near = (q[:, 2] > o["glass_above"]) & ((q[:, 0] - cx) + (q[:, 1] - cy) > 0)
            img, ms, mb = timed(draw, S.select(gr, near))
            glass = np.asarray(R.layer_image(img, (W, H)) if ss > 1 else Image.fromarray(img, "RGBA")).copy()
            glass[..., 3] = np.round(glass[..., 3] * o["glass_alpha"]).astype(np.uint8)
            gr = S.select(gr, ~near)
            ms_total, mb_peak = ms_total + ms, max(mb_peak, mb)
        img, ms, mb = timed(draw, gr)
        body_img = np.asarray(R.layer_image(img, (W, H)) if ss > 1 else Image.fromarray(img, "RGBA"))
        views.append({"rotation": r, "origin": (ox, oy), "size": (W, H), "body": body_img, "glass": glass,
                      "ms": round(ms_total + ms, 1), "peak_vram_mb": max(mb_peak, mb)})
    return views, info


def composite(v: dict) -> np.ndarray:
    """body with its glass_front layer over it (straight alpha), as the game stacks them."""
    if v["glass"] is None:
        return v["body"]
    a = Image.fromarray(v["body"], "RGBA")
    a.alpha_composite(Image.fromarray(v["glass"], "RGBA"))
    return np.asarray(a)


def committed_check(type_id: str, views: list) -> dict:
    """The baseline against assets/generated/fixtures/<type>: crop at the manifest anchor, compare pixels."""
    folder = os.path.join(ROOT, "assets", "generated", "fixtures", type_id)
    man = os.path.join(folder, "%s_a.visual.json" % type_id)
    if not os.path.isfile(man):
        return {"status": "NO_COMMITTED_RENDER"}
    rots = json.load(open(man, encoding="utf-8"))["rotations"]
    out = {}
    for v in views:
        rot = rots[str(v["rotation"])]
        ax, ay = rot["anchor_px"]
        cw, ch = rot["canvas_px"]
        bx0, by0 = round(v["origin"][0] - ax), round(v["origin"][1] - ay)
        mine = v["body"][by0:by0 + ch, bx0:bx0 + cw]
        theirs = np.asarray(Image.open(os.path.join(folder, rot["layers"]["body"])).convert("RGBA"))
        if mine.shape != theirs.shape:
            out[str(v["rotation"])] = {"match": False, "reason": "shape %s vs %s" % (mine.shape, theirs.shape)}
            continue
        d = np.abs(mine.astype(int) - theirs.astype(int)).max(-1)
        out[str(v["rotation"])] = {"match": bool(d.max() <= 1), "max_diff": int(d.max()), "px_over_1": int((d > 1).sum())}
    return out


def run_game(g_raw: dict, type_id: str, opts: dict, conditions: list, backends: list, out: str) -> dict:
    d = fixture_def(type_id)
    rec, base = {}, None
    for name in conditions:
        if not applicable(name, opts):
            continue
        o = dict(opts, **CONDITIONS[name])
        if o["backend"] not in backends:
            rec[name] = {"status": "BLOCKED_BACKEND_UNAVAILABLE", "backend": o["backend"]}
            continue
        views, info = game_render(g_raw, d, o, B.BACKENDS[o["backend"]])
        if name == "baseline":
            base = views
            rec["committed_check"] = committed_check(type_id, views)
        rows = {}
        for v, b in zip(views, base):
            img = composite(v)
            sha = save_png(Image.fromarray(v["body"], "RGBA"), os.path.join(out, "game", "%s_r%d_body.png" % (name, v["rotation"])))
            if v["glass"] is not None:
                save_png(Image.fromarray(v["glass"], "RGBA"), os.path.join(out, "game", "%s_r%d_glass.png" % (name, v["rotation"])))
            rows[str(v["rotation"])] = {"body_png_sha256": sha, "ms": v["ms"], "peak_vram_mb": round(v["peak_vram_mb"], 1),
                                        **metrics(img, None if name == "baseline" else composite(b))}
        rec[name] = {"change": CONDITIONS[name], "info": info, "rotations": rows}
    return rec


# ---------------------------------------------------------------- sheets

def label(im: Image.Image, text: str) -> Image.Image:
    ImageDraw.Draw(im).rectangle((0, 0, im.width, 18), fill=(0, 0, 0))
    ImageDraw.Draw(im).text((4, 3), text, fill=(255, 255, 255))
    return im


def sheet(rows: list, path: str, scale: float = 1.0):
    """rows: [(row label, [PIL images])] -> one JPEG, tiles scaled by `scale`, labelled."""
    tw = max(int(im.width * scale) for _, ims in rows for im in ims)
    th = max(int(im.height * scale) for _, ims in rows for im in ims)
    cols = max(len(ims) for _, ims in rows)
    out = Image.new("RGB", (cols * tw, len(rows) * th), (60, 60, 60))
    for y, (name, ims) in enumerate(rows):
        for x, im in enumerate(ims):
            t = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS) if scale != 1 else im.copy()
            out.paste(label(t, "%s r%d" % (name, x)), (x * tw, y * th))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, quality=88)


def raw_sheets(out: str, backends: list):
    rows = [(n, [over(np.asarray(Image.open(os.path.join(out, "raw", "%s_r%d.png" % (n, r)))), GREY) for r in range(4)]) for n in backends]
    sheet(rows, os.path.join(out, "sheet_raw_grey.jpg"), 0.5)
    # r0 of each backend over black / white / grey, at full size
    bgs = [(0, 0, 0), (255, 255, 255), GREY]
    rows = [(n, [over(np.asarray(Image.open(os.path.join(out, "raw", "%s_r0.png" % n))), bg) for bg in bgs]) for n in backends]
    sheet(rows, os.path.join(out, "sheet_raw_r0_bk_wh_gr.jpg"), 0.5)


def game_sheets(out: str, names: list):
    def img(n, r):
        body = Image.open(os.path.join(out, "game", "%s_r%d_body.png" % (n, r))).convert("RGBA")
        g = os.path.join(out, "game", "%s_r%d_glass.png" % (n, r))
        if os.path.isfile(g):
            body.alpha_composite(Image.open(g).convert("RGBA"))
        return over(np.asarray(body), GREY)
    sheet([(n, [img(n, r) for r in range(4)]) for n in names], os.path.join(out, "sheet_game.jpg"), 0.5)
    # zoom 0.5 / 1 / 1.6 / 2 of rotation 0 (nearest, as a pixel-art camera zoom would show it) for the renderers
    rows = []
    for n in [x for x in ("baseline", "gsplat_classic", "gsplat_aa") if x in names]:
        base = img(n, 0)
        tiles = []
        for z in (0.5, 1.0, 1.6, 2.0):
            zi = base.resize((max(1, int(base.width * z)), max(1, int(base.height * z))), Image.NEAREST if z > 1 else Image.BOX)
            w, h = base.width, base.height          # the centre crop at the 1x canvas size
            l, t = max(0, (zi.width - w) // 2), max(0, (zi.height - h) // 2)
            tile = Image.new("RGB", (w, h), GREY)
            tile.paste(zi.crop((l, t, l + min(w, zi.width), t + min(h, zi.height))), (max(0, (w - zi.width) // 2), max(0, (h - zi.height) // 2)))
            tiles.append(tile)
        rows.append((n + " zoom.5/1/1.6/2", tiles))
    if rows:
        sheet(rows, os.path.join(out, "sheet_game_zoom_r0.jpg"), 0.5)


def environment() -> dict:
    env = {"python": sys.version.split()[0], "torch": torch.__version__, "cuda": torch.version.cuda,
           "device": torch.cuda.get_device_name(0) if torch.cuda.is_available() else "cpu"}
    try:
        import gsplat
        env["gsplat"] = gsplat.__version__
    except ImportError:
        env["gsplat"] = None
    return env


def main():
    p = argparse.ArgumentParser()
    p.add_argument("types", nargs="+")
    p.add_argument("--out", required=True)
    p.add_argument("--src", default=SRC)
    p.add_argument("--stage", default="all", choices=["raw", "game", "all"])
    p.add_argument("--conditions", nargs="*", default=list(CONDITIONS))
    a = p.parse_args()
    cfg = json.load(open(os.path.join(HERE, "fixtures.json"), encoding="utf-8"))
    backends = B.available()
    for type_id in a.types:
        c = cfg[type_id]
        ply = os.path.join(a.src, c["ply"])
        out = os.path.join(a.out, type_id)
        if not os.path.isfile(ply):
            rec = {"type": type_id, "status": "BLOCKED_SOURCE_MISSING", "ply": ply}
        else:
            opts = fixture_options(c)
            t = time.perf_counter()
            g_raw = S.load(ply)
            load_ms = round((time.perf_counter() - t) * 1000, 1)
            warm = raw_scene(S.select(g_raw, torch.arange(0, g_raw["xyz"].shape[0], 50, device=S.DEV)), opts["front_yaw"])
            J, view, origin = raw_camera()
            for name in backends:            # warm-up (CUDA context, gsplat kernels) outside the timings
                B.BACKENDS[name](warm, J, view, origin, RAW_SIZE)
            rec = {"type": type_id, "ply": ply_info.info(ply), "ply_config": c, "options": opts, "load_ms": load_ms,
                   "environment": environment(), "backends": backends}
            if a.stage in ("raw", "all"):
                rec["raw"] = run_raw(g_raw, opts, backends, out)
                raw_sheets(out, backends)
            if a.stage in ("game", "all"):
                rec["game"] = run_game(g_raw, type_id, opts, a.conditions, backends, out)
                game_sheets(out, [n for n in a.conditions if n in rec["game"] and "rotations" in rec["game"][n]])
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "records.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(rec, f, indent=1, ensure_ascii=False)
            f.write("\n")
        print(type_id, rec.get("status", "done"))


if __name__ == "__main__":
    main()
