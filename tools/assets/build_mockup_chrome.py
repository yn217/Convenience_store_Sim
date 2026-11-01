"""Cuts the UI chrome out of the 2026-11-01 mockup screenshots (docs/mockups/ui_target_{goods,data}_2026-11-01.png) for
the game to draw over the live store, as the browser mockup does (its image layer + live values): the top bar, the
left menu, the bottom bar, the 経営管理 window frame and tabs, 小春六花 beside it and her speech bubble.

Everything is worked out at 1920x1080 (the mockup scaled by 1920/1672; the game's base viewport). Each part's outline
is a hand-placed shape refined with GrabCut in a thin band around it, so the store behind shows through the gaps.
Text that changes (date, money, values, the bubble's line, the window's content) is inpainted away and drawn live by
the game. Selected looks the mockup does not show (a selected tab other than 商品 / データ, a selected menu entry
other than 商品, x1 / x2) are made from a selected face with its label inpainted away and the other entry's label
keyed out on top.

Output: assets/ui/mockup/<part>.png plus layout.json ({part: [x, y, w, h]} in 1920x1080 pixels).

    python tools/assets/build_mockup_chrome.py     # needs assets/source/ui_mockup/rikka_cut.png (tools/assets/idol/cutout.py)
"""
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

SRC_GOODS = Path("docs/mockups/ui_target_goods_2026-11-01.png")
SRC_DATA = Path("docs/mockups/ui_target_data_2026-11-01.png")
RIKKA = Path("assets/source/ui_mockup/rikka_cut.png")   # cut from the goods mockup at (170, 285) in its 1672 px space
OUT = Path("assets/ui/mockup")
W, H = 1920, 1080
K = W / 1672                 # mockup px -> game px
CSS = (1672 / 1648) * K      # the browser mockup's hit areas (1648 px wide) -> game px

NAV = [("store", 9, 108, 200, 65), ("goods", 9, 176, 200, 57), ("order", 9, 235, 200, 54), ("management", 9, 291, 200, 55),
       ("data", 9, 348, 200, 57), ("staff", 9, 405, 200, 64), ("equipment", 9, 468, 200, 60), ("achievements", 9, 529, 200, 60)]
TABS = [("goods", 491, 270, 151, 53), ("management", 647, 270, 140, 53), ("store", 790, 270, 136, 53),
        ("staff", 930, 270, 140, 53), ("data", 1076, 270, 146, 53), ("settings", 1225, 270, 141, 53)]
SPEED_BOX = {"pause": [1774, 11, 1808, 55], "x1": [1810, 11, 1841, 55], "x2": [1843, 11, 1874, 55], "x4": [1876, 11, 1910, 55]}
NAV_RIGHT = {"store": 242, "goods": 236}   # the other (brown) buttons end at 224


def inset(box, dx, dy):
    return [box[0] + dx, box[1] + dy, box[2] - dx, box[3] - dy]


def css(x, y, w, h):
    return [x * CSS, y * CSS, (x + w) * CSS, (y + h) * CSS]


def load(path):
    rgb = np.asarray(Image.open(path).convert("RGB").resize((W, H), Image.LANCZOS))
    return np.ascontiguousarray(rgb)


def rrect(mask, box, r, value=1):
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    r = int(min(r, (x1 - x0) // 2, (y1 - y0) // 2))
    cv2.rectangle(mask, (x0 + r, y0), (x1 - r, y1), value, -1)
    cv2.rectangle(mask, (x0, y0 + r), (x1, y1 - r), value, -1)
    for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)):
        cv2.circle(mask, (cx, cy), r, value, -1)


def refine(rgb, rough, band):
    """GrabCut in a band of `band` px around the rough shape: deep inside stays, far outside goes, the band decides."""
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * band + 1, 2 * band + 1))
    inner = cv2.erode(rough, k)
    outer = cv2.dilate(rough, k)
    m = np.full(rough.shape, cv2.GC_BGD, np.uint8)
    m[outer > 0] = cv2.GC_PR_BGD
    m[rough > 0] = cv2.GC_PR_FGD
    m[inner > 0] = cv2.GC_FGD
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), m, None, bgd, fgd, 5, cv2.GC_INIT_WITH_MASK)
    a = np.where((m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)
    a = cv2.morphologyEx(a, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    a = keep_attached(a, inner)
    return cv2.GaussianBlur(a, (3, 3), 0)


def keep_attached(a, inner):
    """Drops specks GrabCut kept that do not touch the part itself."""
    n, labels = cv2.connectedComponents((a > 0).astype(np.uint8))
    keep = set(np.unique(labels[(inner > 0) & (a > 0)])) - {0}
    return np.where(np.isin(labels, list(keep)), a, 0).astype(np.uint8)


def erase(rgb, box, thresh=38, grow=2):
    """Inpaints the strokes (text, numbers) inside `box`: pixels that differ from their row's median surface colour."""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    region = rgb[y0:y1, x0:x1].astype(np.int32)
    med = np.median(region, axis=1, keepdims=True)
    mask = (np.abs(region - med).sum(2) > thresh).astype(np.uint8) * 255
    mask = cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * grow + 1, 2 * grow + 1)))
    full = np.zeros(rgb.shape[:2], np.uint8)
    full[y0:y1, x0:x1] = mask
    rgb[:] = cv2.inpaint(rgb, full, 4, cv2.INPAINT_TELEA)


def fill(rgb, box, src_box=None):
    """Covers `box` with a vertical gradient taken from a strip of plain surface (`src_box`, default: just left of it)."""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    if src_box is None:
        src_box = (x0 - 6, y0, x0 - 2, y1)
    sx0, sy0, sx1, sy1 = [int(round(v)) for v in src_box]
    col = np.median(rgb[sy0:sy1, sx0:sx1].astype(np.float32), axis=1)
    col = cv2.resize(col[None, :, :], (y1 - y0, 1))[0] if len(col) != y1 - y0 else col
    rgb[y0:y1, x0:x1] = col[:, None, :].astype(np.uint8)


def key(rgb, box, light):
    """The light (or dark) strokes of a label as an RGBA patch: alpha from how far a pixel is from the face colour."""
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    region = rgb[y0:y1, x0:x1].astype(np.float32)
    lum = region @ np.array([0.299, 0.587, 0.114], np.float32)
    face = np.median(lum)
    d = (lum - face) if light else (face - lum)
    a = np.clip((d - 18) / 70.0, 0, 1)
    out = np.dstack([region, a * 255]).astype(np.uint8)
    return out


def paste_rgba(rgb, patch, x, y, tint=None):
    h, w = patch.shape[:2]
    a = patch[..., 3:4].astype(np.float32) / 255.0
    src = patch[..., :3].astype(np.float32) if tint is None else np.full_like(patch[..., :3], tint, dtype=np.float32)
    dst = rgb[y:y + h, x:x + w].astype(np.float32)
    rgb[y:y + h, x:x + w] = (src * a + dst * (1 - a)).astype(np.uint8)


def rgba_crop(rgb, alpha, box, name, layout):
    x0, y0, x1, y1 = [int(round(v)) for v in box]
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W, x1), min(H, y1)
    patch = np.dstack([rgb[y0:y1, x0:x1], alpha[y0:y1, x0:x1]])
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(patch).save(OUT / (name + ".png"))
    layout[name] = [x0, y0, x1 - x0, y1 - y0]


# --- shapes (1920 px space) ------------------------------------------------------------------------------------------

def shape_top():
    m = np.zeros((H, W), np.uint8)
    cv2.fillPoly(m, [np.array([(0, 0), (W, 0), (W, 60), (505, 60), (465, 70), (0, 70)], np.int32)], 1)
    return m


def shape_nav(box, badge=False):
    m = np.zeros((H, W), np.uint8)
    x0, y0, x1, y1 = box
    rrect(m, (x0 + 4, y0 + 5, x1 - 4, y1 - 5), 16)
    if badge:   # the red notification dot of the achievements button
        cv2.circle(m, (219, 621), 14, 1, -1)
    return m


def shape_bottom():
    m = np.zeros((H, W), np.uint8)
    rrect(m, (2, 924, W - 2, H), 16)
    return m


def shape_window():
    m = np.zeros((H, W), np.uint8)
    rrect(m, (530, 262, 1619, 882), 30)
    pts = [(580, 271), (580, 235), (603, 218), (965, 218), (1000, 230), (1040, 255), (1619, 255), (1619, 271)]
    cv2.fillPoly(m, [np.array(pts, np.int32)], 1)
    cv2.rectangle(m, (1300, 220), (1479, 266), 1, -1)
    cv2.circle(m, (1562, 271), 38, 1, -1)
    return m


def shape_bubble():
    m = np.zeros((H, W), np.uint8)
    x0, y0, x1, y1 = css(18, 638, 285, 139)
    rrect(m, (x0 - 7, y0 - 5, x1 + 9, y1 + 7), 50)
    rrect(m, (34, 703, 161, 737), 15)
    return m


def main():
    goods = load(SRC_GOODS)
    data = load(SRC_DATA)
    layout = {}

    # Top bar: the values are inpainted away (the captions 所持金 / 本日の売上 … stay).
    top = goods.copy()
    for box in [(498, 22, 592, 52),     # DAY 12
                (612, 22, 735, 52),     # 4月 第2週（春）
                (840, 20, 918, 52),     # 13:40
                (1052, 22, 1160, 52),   # ¥3,549,550
                (1297, 22, 1392, 52),   # ¥210,000
                (1521, 22, 1597, 52),   # ¥80,000
                (1713, 22, 1760, 52)]:  # 24人
        erase(top, box)
    a_top = refine(goods, shape_top(), 7)
    rgba_crop(top, a_top, (0, 0, W, 76), "top_bar", layout)

    # Speed buttons: pause / x1 / x2 unselected and x4 selected in the mockup; the other looks are a face (the blue x4
    # face or the light x2 face, label inpainted away) with the button's own label keyed out on top.
    blue_face = goods.copy()
    erase(blue_face, inset(SPEED_BOX["x4"], 4, 7), thresh=60, grow=3)
    light_face = goods.copy()
    erase(light_face, inset(SPEED_BOX["x2"], 4, 7), thresh=60, grow=3)
    for name, box in SPEED_BOX.items():
        alpha = np.zeros((H, W), np.uint8)
        rrect(alpha, box, 5, 255)
        on = name == "x4"
        rgba_crop(goods, alpha, box, "speed_%s_%s" % (name, "on" if on else "off"), layout)
        face_name, tint, light = ("x2", (40, 32, 40), True) if on else ("x4", (255, 255, 255), False)
        face = light_face if on else blue_face
        label = key(goods, inset(box, 4, 7), light=light)
        canvas = face.copy()
        fb = SPEED_BOX[face_name]
        lw = min(label.shape[1], fb[2] - fb[0] - 8)
        paste_rgba(canvas, label[:, :lw], fb[0] + 4 + ((fb[2] - fb[0] - 8) - lw) // 2, fb[1] + 7, tint=tint)
        alpha = np.zeros((H, W), np.uint8)
        rrect(alpha, fb, 5, 255)
        other = "speed_%s_%s" % (name, "off" if on else "on")
        rgba_crop(canvas, alpha, fb, other, layout)
        layout[other][:2] = box[:2]

    # Left menu: brown buttons, 商品 selected (blue) in the mockup.
    blue = goods.copy()
    gb = [int(round(v)) for v in css(*NAV[1][1:])]
    gb[2] = NAV_RIGHT["goods"]
    erase(blue, (gb[0] + 26, gb[1] + 10, gb[0] + 175, gb[3] - 10), thresh=45, grow=3)
    brown = goods.copy()
    ob = [int(round(v)) for v in css(*NAV[2][1:])]
    ob[2] = 224
    erase(brown, (ob[0] + 26, ob[1] + 10, ob[0] + 175, ob[3] - 10), thresh=45, grow=3)
    for name, *box in NAV:
        b = [int(round(v)) for v in css(*box)]
        b[2] = NAV_RIGHT.get(name, 224)
        alpha = refine(goods, shape_nav(b, name == "achievements"), 5)
        if name == "goods":
            rgba_crop(goods, alpha, b, "nav_goods_on", layout)
            off = brown.copy()
            paste_rgba(off, key(goods, (gb[0] + 26, gb[1] + 10, gb[0] + 170, gb[3] - 10), light=True), ob[0] + 26, ob[1] + 10 - ((gb[3] - gb[1]) - (ob[3] - ob[1])) // 2,
                       tint=(255, 240, 220))
            a2 = refine(goods, shape_nav(ob), 5)
            rgba_crop(off, a2, ob, "nav_goods_off", layout)
            layout["nav_goods_off"][:2] = layout["nav_goods_on"][:2]
            continue
        rgba_crop(goods, alpha, b, "nav_%s_off" % name, layout)
        on = blue.copy()
        paste_rgba(on, key(goods, (b[0] + 26, b[1] + 10, b[0] + 170, b[3] - 10), light=True), gb[0] + 26, gb[1] + 10 + (gb[3] - gb[1] - (b[3] - b[1])) // 2,
                   tint=(255, 255, 255))
        a2 = refine(goods, shape_nav(gb), 5)
        rgba_crop(on, a2, gb, "nav_%s_on" % name, layout)
        layout["nav_%s_on" % name][:2] = [b[0], b[1] + ((b[3] - b[1]) - (gb[3] - gb[1])) // 2]

    # Bottom bar: the goal line, the progress and the four values are drawn live; the event banner's words and picture
    # too (the pink face stays); the four buttons on the right stay as drawn.
    bot = goods.copy()
    for box in [(55, 975, 330, 1006),    # 累計10件の会計を達成しよう！
                (298, 1011, 352, 1038),  # 10%
                (448, 990, 555, 1024), (627, 990, 718, 1024), (800, 990, 862, 1024), (955, 990, 1022, 1026),
                (1108, 968, 1345, 1044)]:   # the event's name and effect
        erase(bot, box)
    erase(bot, (1345, 945, 1462, 1048), thresh=30, grow=4)   # the event's picture (the game draws today's)
    track = bot[1022, 200].copy()
    bot[1016:1030, 47:110] = track   # the progress fill (the game draws the real one)
    rgba_crop(bot, refine(goods, shape_bottom(), 7), (0, 918, W, H), "bottom_bar", layout)

    # Window frame: the content below the tabs is drawn live, the tabs are their own images.
    win = goods.copy()
    top_c = np.median(goods[300:306, 600:1500].reshape(-1, 3), axis=0)
    bot_c = np.median(goods[835:860, 554:559].reshape(-1, 3), axis=0)
    t = np.linspace(0, 1, 868 - 300)[:, None]
    win[300:868, 552:1600] = ((1 - t) * top_c + t * bot_c)[:, None, :].astype(np.uint8)
    a_win = refine(goods, shape_window(), 7)
    rgba_crop(win, a_win, (520, 205, 1630, 892), "window", layout)

    for src, picked in ((goods, "goods"), (data, "data")):
        for name, *box in TABS:
            b = [int(round(v)) for v in css(*box)]
            alpha = np.zeros((H, W), np.uint8)
            rrect(alpha, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2), 10, 255)
            state = "on" if name == picked else "off"
            if ("tab_%s_%s" % (name, state)) not in layout:
                rgba_crop(src, alpha, b, "tab_%s_%s" % (name, state), layout)
    yellow = goods.copy()
    gt = [int(round(v)) for v in css(*TABS[0][1:])]
    erase(yellow, (gt[0] + 12, gt[1] + 8, gt[2] - 12, gt[3] - 8), thresh=50, grow=3)
    for name, *box in TABS:
        if "tab_%s_on" % name in layout:
            continue
        b = [int(round(v)) for v in css(*box)]
        lab = key(goods, (b[0] + 10, b[1] + 8, b[2] - 10, b[3] - 8), light=False)
        canvas = yellow.copy()
        w = min(lab.shape[1], gt[2] - gt[0] - 20)
        paste_rgba(canvas, lab[:, :w], gt[0] + 10 + ((gt[2] - gt[0] - 20) - w) // 2, gt[1] + 8)
        alpha = np.zeros((H, W), np.uint8)
        rrect(alpha, (gt[0] + 2, gt[1] + 2, gt[2] - 2, gt[3] - 2), 10, 255)
        rgba_crop(canvas, alpha, gt, "tab_%s_on" % name, layout)
        layout["tab_%s_on" % name][:2] = [b[0], b[1]]

    # 小春六花 and her speech bubble (the bubble's line is drawn live).
    cut = np.asarray(Image.open(RIKKA).convert("RGBA"))
    big = Image.fromarray(cut).resize((round(cut.shape[1] * K), round(cut.shape[0] * K)), Image.LANCZOS)
    big.save(OUT / "rikka.png")
    layout["rikka"] = [round(170 * K), round(285 * K), big.width, big.height]
    bub = goods.copy()
    x0, y0, x1, y1 = css(18, 638, 285, 139)
    a_bub = refine(goods, shape_bubble(), 6)
    inside = cv2.erode((a_bub > 128).astype(np.uint8), cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25)))
    inside[:745] = 0   # the 小春 name tag stays
    ys, xs = np.nonzero(inside)
    c0 = np.median(goods[ys.min():ys.min() + 3, xs.min() + 20:xs.max() - 20].reshape(-1, 3), axis=0)
    c1 = np.median(goods[ys.max() - 3:ys.max(), xs.min() + 20:xs.max() - 20].reshape(-1, 3), axis=0)
    t = ((np.arange(H) - ys.min()) / max(1, ys.max() - ys.min())).clip(0, 1)[:, None]
    grad = ((1 - t) * c0 + t * c1).astype(np.uint8)
    bub[inside > 0] = grad[ys]
    rgba_crop(bub, a_bub, (8, 690, 382, 900), "bubble", layout)

    (OUT / "layout.json").write_text(json.dumps(layout, indent=1), encoding="utf-8")
    print(len(layout), "parts")


if __name__ == "__main__":
    main()
