"""Builds the 限定くじ管理 screen art (#138) from the user's mockup.

The left menu is cut off (x < 190), and every value that changes in play is erased so Godot can draw it live:
the status chip, the dates, the prizes left with their bars, the four set values and Rikka's line. Rikka's hand
over the B row is kept and also saved alone (kuji_hand.png) to draw above the live bar.

    python tools/assets/build_kuji_screen.py
"""
import numpy as np
from PIL import Image

SRC = "assets/source/mockups/kuji_screen_rikka_source.png"
OUT = "assets/ui/kuji/kuji_screen.png"
HAND = "assets/ui/kuji/kuji_hand.png"
CUT_X = 190
# Rectangles in source pixels (x0, y0, x1, y1), all erased by vertical interpolation of the rows above and below.
ERASE = [
    (865, 113, 1100, 154),    # 販売中 chip
    (962, 163, 1102, 200),    # 4/15〜4/30
    (1066, 374, 1258, 424),   # A: 3 / 5 and its bar
    (1066, 464, 1258, 516),   # B
    (1066, 558, 1258, 608),   # C
    (1066, 653, 1258, 704),   # D
    (293, 756, 442, 802),     # 35,000円
    (523, 756, 642, 802),     # 50枚
    (723, 756, 842, 802),     # 23枚
    (908, 756, 1137, 802),    # 4/29 頃
]
BUBBLE = (1396, 640, 1645, 860)   # Rikka's line: the dark text is whitened, the stars stay
HAND_BOX = (1150, 440, 1300, 540)


def skin(px):
    r, g, b = px[..., 0].astype(int), px[..., 1].astype(int), px[..., 2].astype(int)
    return (r - b > 14) & (r > 140) & (g > 80) & (r >= g)


def main():
    im = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    orig = im.copy()
    keep = np.zeros(im.shape[:2], bool)
    hx0, hy0, hx1, hy1 = HAND_BOX
    keep[hy0:hy1, hx0:hx1] = skin(orig[hy0:hy1, hx0:hx1])
    from scipy import ndimage
    keep = ndimage.binary_fill_holes(ndimage.binary_closing(keep, iterations=3))
    for x0, y0, x1, y1 in ERASE:
        top, bottom = im[y0 - 1, x0:x1], im[y1, x0:x1]
        for i, y in enumerate(range(y0, y1)):
            t = (i + 1) / (y1 - y0 + 1)
            row = top * (1 - t) + bottom * t
            mask = ~keep[y, x0:x1]
            im[y, x0:x1][mask] = row[mask]
    bx0, by0, bx1, by1 = BUBBLE
    reg = im[by0:by1, bx0:bx1]
    # The bubble is the white region around its centre; filling its holes takes in the letters (and the stars).
    white = reg.min(axis=2) > 215
    lab, _n = ndimage.label(white)
    inside = ndimage.binary_fill_holes(lab == lab[(by1 - by0) // 2, 8])
    inside = ndimage.binary_erosion(inside, iterations=3)   # keep the bubble's own outline
    yellow = (reg[..., 0] > 190) & (reg[..., 2] < 170) & (reg[..., 0] - reg[..., 2] > 60)
    yellow = ndimage.binary_dilation(yellow, iterations=2)
    reg[inside & ~yellow] = 255.0
    Image.fromarray(im[:, CUT_X:].clip(0, 255).astype(np.uint8)).save(OUT)
    # The hand alone, full canvas size so it lines up with the screen.
    alpha = np.zeros(im.shape[:2], np.uint8)
    alpha[keep] = 255
    alpha = ndimage.gaussian_filter(alpha.astype(np.float32), 0.6).clip(0, 255).astype(np.uint8)
    hand = np.dstack([orig.astype(np.uint8), alpha])[hy0:hy1, :][:, CUT_X:]
    full = np.zeros((im.shape[0], im.shape[1] - CUT_X, 4), np.uint8)
    full[hy0:hy1] = hand
    Image.fromarray(full[hy0:hy1, hx0 - CUT_X:hx1 - CUT_X], "RGBA").save(HAND)
    print("saved", OUT, HAND, "hand origin", (hx0 - CUT_X, hy0))


if __name__ == "__main__":
    main()
