"""Build reusable product-shape sprites for slot overlays.

The generator intentionally creates shape templates, not SKU-specific baked shelf art.
Products are rendered at source resolution (2x the 128x64 tile contract) with transparent
backgrounds and four facing variants so the presentation layer can reuse one shape for many
SKUs and rotate it with the fixture slot.
"""
import hashlib
import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "generated" / "products"
SIZE = 256
SHAPES = {
    "onigiri_triangle": ((0.105, 0.045, 0.095), (238, 238, 232), (196, 45, 48), "RICE"),
    "oden_piece": ((0.085, 0.085, 0.045), (221, 160, 78), (145, 78, 35), "ODEN"),
    "cup_noodle": ((0.110, 0.110, 0.120), (239, 221, 172), (188, 64, 42), "CUP"),
    "bread_bag": ((0.170, 0.085, 0.090), (224, 173, 99), (111, 61, 33), "BREAD"),
    "bottle_500": ((0.068, 0.068, 0.225), (151, 205, 224), (34, 96, 148), "DRINK"),
    "snack_pouch": ((0.130, 0.055, 0.215), (242, 177, 54), (194, 67, 42), "SNACK"),
    "dessert_cup": ((0.100, 0.100, 0.115), (245, 224, 190), (167, 87, 107), "DESSERT"),
    "ice_bar_pack": ((0.080, 0.025, 0.175), (218, 239, 246), (63, 131, 178), "ICE"),
}
CATEGORY_SHAPES = {
    "rice_ball": "onigiri_triangle",
    "oden": "oden_piece",
    "instant_noodle": "cup_noodle",
    "bread": "bread_bag",
    "drink": "bottle_500",
    "snack": "snack_pouch",
    "dessert": "dessert_cup",
    "ice_cream": "ice_bar_pack",
}


def _font(size):
    try:
        return ImageFont.truetype("arial.ttf", size)
    except OSError:
        return ImageFont.load_default()


def _shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color)


def _draw_shape(shape_id, rotation):
    dims, base, accent, label = SHAPES[shape_id]
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    # Product footprint is deliberately small relative to the source tile.
    w = max(28, int(100 * dims[0] / 0.17))
    h = max(24, int(130 * dims[2] / 0.225))
    cx, bottom = SIZE // 2, 188
    left, right = cx - w // 2, cx + w // 2
    top = bottom - h
    light = 1.04 if rotation in (0, 1) else 0.94
    edge = _shade(base, 0.70 * light)
    dark = _shade(base, 0.52 * light)
    d.ellipse((left - 5, bottom - 4, right + 5, bottom + 8), fill=(20, 24, 28, 75))
    if shape_id == "onigiri_triangle":
        poly = [(cx, top), (right, bottom), (left, bottom)]
        d.polygon(poly, fill=base + (255,), outline=edge + (255,))
        d.line([(cx, top + 8), (cx, bottom - 5)], fill=(255, 255, 255, 100), width=3)
    elif shape_id == "bottle_500":
        neck = max(8, w // 3)
        d.rounded_rectangle((left, top + 12, right, bottom), radius=w // 4, fill=base + (255,), outline=edge + (255,), width=3)
        d.rounded_rectangle((cx - neck // 2, top, cx + neck // 2, top + 20), radius=3, fill=dark + (255,))
    elif shape_id == "dessert_cup":
        d.ellipse((left, top, right, top + 14), fill=_shade(base, 1.12) + (255,), outline=edge + (255,))
        d.polygon([(left, top + 7), (right, top + 7), (right - 8, bottom), (left + 8, bottom)], fill=base + (255,), outline=edge + (255,))
    else:
        d.rounded_rectangle((left, top, right, bottom), radius=max(4, w // 8), fill=base + (255,), outline=edge + (255,), width=3)
        d.line((left + 5, top + 5, left + 5, bottom - 5), fill=(255, 255, 255, 105), width=3)
        if shape_id == "cup_noodle":
            d.ellipse((left + 3, top - 4, right - 3, top + 13), fill=_shade(base, 1.1) + (255,), outline=edge + (255,))
    # Fictional, deliberately generic label; no real brand or trademark.
    band_y = top + max(12, h // 2)
    d.rectangle((left + 3, band_y, right - 3, band_y + max(10, h // 7)), fill=accent + (235,))
    f = _font(max(8, min(13, w // 5)))
    text_box = d.textbbox((0, 0), label, font=f)
    tx = cx - (text_box[2] - text_box[0]) // 2
    d.text((tx, band_y + 1), label, fill=(255, 255, 255, 235), font=f)
    # Directional highlight keeps the four variants deterministic but visibly distinct.
    if rotation in (1, 2):
        d.line((right - 4, top + 8, right - 4, bottom - 8), fill=(255, 255, 255, 90), width=3)
    else:
        d.line((left + 4, top + 8, left + 4, bottom - 8), fill=(255, 255, 255, 90), width=3)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for shape_id in SHAPES:
        dest = OUT / shape_id
        dest.mkdir(exist_ok=True)
        dims = SHAPES[shape_id][0]
        manifest = {"manifest_version": 1, "shape_id": shape_id, "projection_id": "iso2x_v1", "dimensions_m": {"width": dims[0], "depth": dims[1], "height": dims[2]}, "source_px_per_tile": [256, 128], "directions": {}}
        for rotation in range(4):
            name = f"{shape_id}_{rotation}.png"
            _draw_shape(shape_id, rotation).save(dest / name, "PNG", optimize=True)
            manifest["directions"][str(rotation)] = name
        (dest / f"{shape_id}.product.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    catalog = json.loads((ROOT / "data" / "products" / "mvp_v1.json").read_text(encoding="utf-8"))
    sku_manifest = {"manifest_version": 1, "source_catalog": "data/products/mvp_v1.json", "mapping_policy": "category_to_shared_shape", "products": {}}
    for product in catalog:
        shape_id = CATEGORY_SHAPES[product["category"]]
        sku_manifest["products"][product["visual_id"]] = {"sku_id": product["sku_id"], "shape_id": shape_id, "directions": {str(r): f"{shape_id}/{shape_id}_{r}.png" for r in range(4)}}
    (OUT / "products_manifest.json").write_text(json.dumps(sku_manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    files = sorted(str(p.relative_to(ROOT)).replace("\\", "/") for p in OUT.rglob("*.py"))
    provenance = {"projection_id": "iso2x_v1", "source_type": "procedural_pillow", "shape_count": len(SHAPES), "directions_per_shape": 4, "sku_count": len(catalog), "generator": "tools/assets/build_products.py", "generator_sha256_16": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()[:16], "third_party_art": False, "notes": "Generic fictional labels only; no real brands or external images. SKU mapping is category-based and does not bake products into fixture art."}
    (OUT / "PROVENANCE.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"built {len(SHAPES)} product shapes x 4 directions")


if __name__ == "__main__":
    main()
