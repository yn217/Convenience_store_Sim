"""Measures the drawn extent of each text and icon of the 2026-11-01 mockup and of a game capture in the same place, so
sizes and positions can be matched by number, not by eye. For each element: a search box (1920x1080 px) that holds
only that element on its plain face; the "ink" is every pixel that differs clearly from the box's median colour.
Prints the ink box (x, y, w, h) of both and the differences; h_ratio = mockup / game height (> 1: the game's is too
small).

    python tools/qa/measure_mockup.py <capture.png> <goods|data>
"""
import sys

import numpy as np
from PIL import Image

COMMON = {
    # top bar
    "title": (86, 4, 450, 36), "subtitle": (86, 37, 440, 57), "logo": (6, 0, 84, 64),
    "day_text": (502, 16, 602, 54), "calendar": (462, 16, 502, 54), "date": (606, 16, 740, 54), "sakura": (740, 8, 788, 58),
    "moon": (804, 14, 844, 56), "clock": (844, 14, 936, 56),
    "coins": (948, 12, 994, 58), "cash_cap": (994, 18, 1046, 52), "cash": (1048, 16, 1168, 54),
    "sales_icon": (1180, 14, 1220, 56), "sales_cap": (1220, 18, 1294, 52), "sales": (1294, 16, 1400, 54),
    "arrow": (1410, 12, 1450, 58), "profit_cap": (1448, 18, 1518, 52), "profit": (1518, 16, 1602, 54),
    "person": (1612, 12, 1656, 58), "visitors_cap": (1654, 18, 1712, 52), "visitors": (1712, 16, 1766, 54),
    # menu (icon, label) per entry
    **{"nav_%d_icon" % i: (30, 142 + i * 67, 84, 186 + i * 67) for i in range(8)},
    **{"nav_%d_text" % i: (92, 145 + i * 67, 222, 183 + i * 67) for i in range(8)},
    # bubble
    "bubble_name": (72, 706, 150, 734), "bubble_text": (34, 746, 350, 892),
    # bottom bar
    "goal_title": (96, 930, 330, 962), "goal_text": (40, 970, 350, 1006), "goal_pct": (292, 1008, 354, 1040),
    "kpi1_cap": (430, 950, 556, 984), "kpi1_val": (436, 986, 556, 1028), "kpi1_icon": (390, 976, 440, 1030),
    "kpi2_cap": (606, 950, 724, 984), "kpi2_val": (614, 986, 724, 1028), "kpi2_icon": (570, 976, 616, 1030),
    "kpi3_cap": (776, 950, 876, 984), "kpi3_val": (782, 986, 876, 1028), "kpi3_icon": (738, 976, 784, 1030),
    "kpi4_cap": (930, 950, 1036, 984), "kpi4_val": (936, 986, 1036, 1028), "kpi4_icon": (890, 976, 938, 1030),
    "corner_bell": (1506, 934, 1590, 1000), "corner_text1": (1502, 1002, 1594, 1036),
    # window header
    "win_title": (680, 222, 870, 290), "win_sub": (874, 252, 1010, 276), "win_icon": (590, 206, 680, 300),
    **{"tab_%d" % i: b for i, b in enumerate([(578, 322, 744, 370), (760, 322, 912, 370), (926, 322, 1074, 370),
                                                (1090, 322, 1242, 370), (1260, 322, 1418, 370), (1432, 322, 1586, 370)])},
}
GOODS = {
    "rib1_text": (650, 400, 800, 440), "rib1_icon": (590, 396, 646, 444), "backroom": (946, 404, 1170, 440), "backroom_icon": (900, 400, 940, 444),
    "drop_text": (710, 470, 1000, 510), "drop_icon": (612, 462, 708, 516), "qty": (1240, 470, 1290, 506),
    "order_text": (1450, 466, 1550, 510), "order_icon": (1384, 460, 1450, 514),
    "rib2_text": (636, 560, 770, 604), "rib2_sub": (790, 566, 1012, 598),
    "head_price": (1050, 574, 1140, 600), "head_cost": (1192, 574, 1240, 600), "head_margin": (1278, 574, 1326, 600), "head_rate": (1360, 574, 1440, 600),
    "row1_name": (680, 616, 900, 652), "row1_icon": (590, 606, 680, 662), "row1_price": (1040, 618, 1124, 654),
    "row1_cost": (1190, 618, 1250, 654), "row1_margin": (1270, 618, 1350, 654), "row1_rate": (1360, 618, 1450, 654),
    "row1_btn": (1480, 620, 1570, 650),
}
DATA = {
    "rib_text": (600, 396, 780, 432), "date_text": (936, 398, 1200, 432),
    "kpi1_cap": (650, 452, 740, 482), "kpi1_val": (640, 482, 810, 524), "kpi1_icon": (584, 450, 650, 520),
    "kpi1_delta": (600, 528, 810, 552),
    "chart_title": (588, 570, 760, 600), "axis_top": (560, 600, 660, 628),
    "rank_title": (610, 752, 820, 790), "rank1_name": (700, 800, 820, 846), "rank1_qty": (818, 812, 880, 844),
}


def ink_box(img, box, mode):
    """mode L: light text (luminance > 185), D: dark text (< 95), G: gold figures (yellow), I: an icon (differs from
    the box's median colour)."""
    x0, y0, x1, y1 = box
    a = img[y0:y1, x0:x1].astype(np.int32)
    lum = a @ np.array([299, 587, 114]) / 1000
    if mode == "L":
        mask = lum > 185
    elif mode == "D":
        mask = lum < 95
    elif mode == "G":
        mask = (a[..., 0] > 190) & (a[..., 1] > 150) & (a[..., 2] < 140)
    else:
        med = np.median(a.reshape(-1, 3), axis=0)
        mask = np.abs(a - med).sum(2) > 90
    ys, xs = np.nonzero(mask)
    if len(xs) < 4:
        return None
    return (x0 + int(xs.min()), y0 + int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1))


MODES = {"cash": "G", "sales": "G", "profit": "G", "kpi1_val": "G", "kpi2_val": "G", "kpi3_val": "G", "kpi4_val": "G"}
LIGHT = ("title", "subtitle", "day_text", "date", "clock", "cash_cap", "sales_cap", "profit_cap", "visitors_cap", "visitors",
         "nav_", "goal_title", "kpi1_cap", "kpi2_cap", "kpi3_cap", "kpi4_cap", "corner_text", "win_title", "win_sub",
         "rib1_text", "rib2_text", "rib2_sub", "rib_text", "bubble_name", "order_text")


def mode_of(name):
    if name in MODES:
        return MODES[name]
    if "icon" in name or name in ("logo", "calendar", "sakura", "moon", "coins", "arrow", "person", "corner_bell"):
        return "I"
    if name.startswith(LIGHT) and not name.endswith("_icon"):
        return "L"
    return "D"


def main() -> None:
    cap = np.asarray(Image.open(sys.argv[1]).convert("RGB").resize((1920, 1080)))
    tab = sys.argv[2]
    mock = np.asarray(Image.open("docs/mockups/ui_target_%s_2026-11-01.png" % tab).convert("RGB").resize((1920, 1080), Image.LANCZOS))
    elems = {**COMMON, **(GOODS if tab == "goods" else DATA)}
    print("%-14s %-22s %-22s %6s %6s %6s" % ("element", "mockup x,y,w,h", "game x,y,w,h", "dx", "dy", "h_rat"))
    for name, box in elems.items():
        md = mode_of(name)
        m, g = ink_box(mock, box, md), ink_box(cap, box, md)
        if m is None or g is None:
            print("%-14s %-22s %-22s" % (name, m, g))
            continue
        print("%-14s %-22s %-22s %6d %6d %6.2f" % (name, "%d,%d,%d,%d" % m, "%d,%d,%d,%d" % g, m[0] - g[0], m[1] - g[1], m[3] / g[3]))


if __name__ == "__main__":
    main()
