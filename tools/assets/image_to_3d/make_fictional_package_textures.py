"""Generate deterministic, fictional front-label bitmaps for the gondola comparison.

Run with the pixal3d Pillow environment:
    micromamba run -p /home/inayut/.local/envs/pixal3d python \
        tools/assets/image_to_3d/make_fictional_package_textures.py \
        --out build/issue123-image-to-3d/procedural/textures

All artwork is drawn locally with Pillow; no downloaded artwork, trademarks, or real brands.
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFont

W, H = 512, 768
INK = (25, 36, 47)
CREAM = (255, 246, 218)

PRODUCTS = [
    {"file": "snack_01.png", "brand": "KOMOREBI", "category": "RICE CRISPS", "flavor": "SEA SALT",
     "bg": (246, 190, 48), "dark": (32, 83, 107), "food": "crisps", "badge": "CRUNCHY"},
    {"file": "snack_02.png", "brand": "HARU", "category": "BUTTER CORN", "flavor": "SWEET CORN",
     "bg": (255, 221, 92), "dark": (136, 61, 35), "food": "corn", "badge": "BAKED"},
    {"file": "snack_03.png", "brand": "KOMOREBI", "category": "MATCHA COOKIES", "flavor": "GREEN TEA",
     "bg": (116, 174, 91), "dark": (34, 68, 48), "food": "cookies", "badge": "8 PIECES"},
    {"file": "snack_04.png", "brand": "HARU", "category": "BERRY TART", "flavor": "MIXED BERRY",
     "bg": (220, 83, 105), "dark": (93, 33, 61), "food": "berries", "badge": "FRUITY"},
    {"file": "snack_05.png", "brand": "KOMOREBI", "category": "SOY CRACKERS", "flavor": "SESAME SOY",
     "bg": (74, 157, 155), "dark": (26, 65, 76), "food": "crackers", "badge": "SAVORY"},
    {"file": "snack_06.png", "brand": "HARU", "category": "HONEY TOAST", "flavor": "RICH HONEY",
     "bg": (238, 143, 47), "dark": (103, 48, 35), "food": "toast", "badge": "GOLDEN"},
    {"file": "snack_07.png", "brand": "KOMOREBI", "category": "CITRUS GUMMIES", "flavor": "YUZU CITRUS",
     "bg": (248, 190, 51), "dark": (35, 106, 92), "food": "citrus", "badge": "CHEWY"},
    {"file": "snack_08.png", "brand": "HARU", "category": "MILK BREAD", "flavor": "MILK & VANILLA",
     "bg": (246, 221, 187), "dark": (113, 67, 44), "food": "bread", "badge": "SOFT BAKE"},
]


def font(size, bold=False):
    paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for path in paths:
        if os.path.isfile(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


def center_text(draw, xy, text, fnt, fill, stroke_width=0, stroke_fill=None):
    draw.text(xy, text, font=fnt, fill=fill, anchor="mm", align="center",
              stroke_width=stroke_width, stroke_fill=stroke_fill)


def food_art(draw, kind, cx, cy, color):
    """Small high-contrast vector food vignette, deterministic for each label family."""
    dark = color["dark"]
    cream = CREAM
    # A light medallion anchors the illustration and separates it from the color field.
    draw.ellipse((cx-166, cy-166, cx+166, cy+166), fill=cream, outline=dark, width=9)
    if kind in ("crisps", "corn", "cookies", "crackers", "toast", "bread"):
        for dx, dy, radius in ((-62, -25, 67), (48, -44, 69), (-8, 56, 72)):
            fill = (242, 177, 65) if kind != "bread" else (226, 168, 105)
            draw.ellipse((cx+dx-radius, cy+dy-radius, cx+dx+radius, cy+dy+radius),
                         fill=fill, outline=dark, width=8)
            if kind in ("crisps", "crackers"):
                for sx, sy in ((-20, -15), (18, 20), (0, -38)):
                    draw.ellipse((cx+dx+sx-7, cy+dy+sy-7, cx+dx+sx+7, cy+dy+sy+7), fill=dark)
            elif kind == "cookies":
                for sx, sy in ((-22, -18), (20, -8), (-4, 24)):
                    draw.ellipse((cx+dx+sx-10, cy+dy+sy-10, cx+dx+sx+10, cy+dy+sy+10), fill=dark)
            elif kind == "corn":
                for sx in (-27, 0, 27):
                    draw.ellipse((cx+dx+sx-6, cy+dy-8, cx+dx+sx+6, cy+dy+8), fill=(255, 228, 113))
            elif kind in ("toast", "bread"):
                draw.arc((cx+dx-35, cy+dy-40, cx+dx+35, cy+dy+40), 195, 345, fill=cream, width=9)
    elif kind == "berries":
        for dx, dy, shade in ((-65, -20, (203, 43, 75)), (0, -55, (128, 46, 111)),
                              (63, -5, (216, 53, 64)), (-20, 65, (185, 49, 93)), (61, 75, (139, 45, 96))):
            draw.ellipse((cx+dx-43, cy+dy-43, cx+dx+43, cy+dy+43), fill=shade, outline=dark, width=6)
            draw.ellipse((cx+dx-13, cy+dy-17, cx+dx-1, cy+dy-5), fill=(255, 200, 182))
        draw.arc((cx-65, cy-117, cx+61, cy-16), 195, 340, fill=(47, 119, 65), width=13)
    elif kind == "citrus":
        for dx, dy, rad, fill in ((-53, 0, 75, (255, 170, 39)), (56, 21, 64, (245, 123, 42))):
            draw.ellipse((cx+dx-rad, cy+dy-rad, cx+dx+rad, cy+dy+rad), fill=fill, outline=dark, width=7)
            draw.ellipse((cx+dx-rad+12, cy+dy-rad+12, cx+dx+rad-12, cy+dy+rad-12),
                         outline=CREAM, width=6)
            for angle in range(0, 360, 45):
                import math
                import_x = cx+dx + math.cos(math.radians(angle))*rad*0.78
                import_y = cy+dy + math.sin(math.radians(angle))*rad*0.78
                draw.line((cx+dx, cy+dy, import_x, import_y), fill=CREAM, width=5)


def make_label(product, index):
    image = Image.new("RGB", (W, H), product["bg"])
    d = ImageDraw.Draw(image)
    dark = product["dark"]
    # Edge frame and a deep brand header create crisp, readable shelf facings.
    d.rounded_rectangle((14, 14, W-15, H-15), radius=28, outline=dark, width=12)
    d.rounded_rectangle((24, 24, W-25, 143), radius=24, fill=dark)
    center_text(d, (W//2, 82), product["brand"], font(39 if product["brand"] == "KOMOREBI" else 62, True), CREAM)
    center_text(d, (W//2, 183), product["category"], font(29, True), dark)
    # Two small graphic ticks and a flavor ribbon establish hierarchy at thumbnail size.
    d.rounded_rectangle((42, 220, W-43, 270), radius=18, fill=CREAM, outline=dark, width=3)
    center_text(d, (W//2, 245), product["flavor"], font(25, True), dark)
    food_art(d, product["food"], W//2, 442, product)
    d.rounded_rectangle((83, 586, W-84, 645), radius=22, fill=dark)
    center_text(d, (W//2, 616), product["badge"], font(25, True), CREAM)
    d.rectangle((24, 673, W-25, H-25), fill=dark)
    center_text(d, (W//2, 708), "FICTIONAL PANTRY  /  70 g", font(18, True), CREAM)
    # SKU stripe is encoded in art, not a logo or machine-readable barcode.
    for i in range(7):
        x = 38 + i*18
        d.rectangle((x, 739, x+9, 755), fill=product["bg"] if (i+index) % 2 else CREAM)
    return image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="Directory for deterministic PNG label textures")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for index, product in enumerate(PRODUCTS):
        path = os.path.join(args.out, product["file"])
        make_label(product, index).save(path, format="PNG", optimize=True)
        print("WROTE", path)


if __name__ == "__main__":
    main()
