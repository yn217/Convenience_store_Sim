"""Draws a contact sheet for visual review: every type, 4 rotations side by side, layers
composited in game order (shadow, body, glass_front) over grey, with the anchor (red cross)
and the projected footprint outline (cyan) overlaid. The common ground line makes scale and
anchor mistakes obvious.

    python tools/assets/contact_sheet.py --dir assets/generated/fixtures --out sheet.png
"""
import argparse
import glob
import json
import os

from PIL import Image, ImageDraw

ORDER = ("shadow", "body", "glass_front")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    manifests = sorted(glob.glob(os.path.join(args.dir, "*", "*.visual.json")))
    loaded = []
    for mpath in manifests:
        with open(mpath, encoding="utf-8") as f:
            loaded.append(json.load(f))
    rots = [rot for m in loaded for rot in m["rotations"].values()]
    margin = 10
    cell_w = max(r["canvas_px"][0] for r in rots) + 20
    cell_h = max(r["canvas_px"][1] for r in rots) + 20
    max_ax = max(r["anchor_px"][0] for r in rots) + 10
    max_ay = max(r["anchor_px"][1] for r in rots) + 10
    rows = len(manifests)
    sheet = Image.new("RGBA", (cell_w * 4 + margin * 5, (cell_h + margin) * rows + margin), (150, 156, 150, 255))
    draw = ImageDraw.Draw(sheet)
    for row, (mpath, m) in enumerate(zip(manifests, loaded)):
        base = os.path.dirname(mpath)
        for r in range(4):
            rot = m["rotations"][str(r)]
            ax, ay = rot["anchor_px"]
            # Put the anchor at a fixed spot of the cell so ground lines up across rotations.
            gx = margin + r * (cell_w + margin) + int(max_ax)
            gy = margin + row * (cell_h + margin) + int(max_ay)
            for name in ORDER:
                if name in rot["layers"]:
                    img = Image.open(os.path.join(base, rot["layers"][name])).convert("RGBA")
                    layer = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
                    layer.paste(img, (int(round(gx - ax)), int(round(gy - ay))))
                    sheet = Image.alpha_composite(sheet, layer)
            draw = ImageDraw.Draw(sheet)
            poly = [(gx + x - ax, gy + y - ay) for x, y in rot["selection_polygon_px"]]
            draw.line(poly + [poly[0]], fill=(0, 220, 255, 255), width=2)
            draw.line([(gx - 8, gy), (gx + 8, gy)], fill=(255, 0, 0, 255), width=2)
            draw.line([(gx, gy - 8), (gx, gy + 8)], fill=(255, 0, 0, 255), width=2)
            draw.text((margin + r * (cell_w + margin) + 6, margin + row * (cell_h + margin) + 4), "%s r%d" % (m["fixture_type_id"], r), fill=(0, 0, 0, 255))
    sheet.convert("RGB").save(args.out)
    print("wrote", args.out)


if __name__ == "__main__":
    main()
