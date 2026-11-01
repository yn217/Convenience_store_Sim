"""Cuts the product renders (tools/assets/comfy_products.py) out of their white background into the UI icons:
assets/ui/products/<sku_id>.png, 64x64 (2x the 32 px rows), centred, transparent. A larger-size SKU (<id>_up) uses
its base product's picture.

    python tools/assets/build_product_icons.py
"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import build_chibi_sprites as chibi  # noqa: E402  (its cut(): white background flood fill)
import comfy_products as prod  # noqa: E402

SIZE = 64
PAD = 2
SEED = 9301


def icon(src: Path) -> Image.Image:
    fig = chibi.cut(src)
    fig = fig.crop(fig.getbbox())
    k = (SIZE - 2 * PAD) / max(fig.width, fig.height)
    small = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
    return canvas


def main() -> None:
    out = Path("assets/ui/products")
    out.mkdir(parents=True, exist_ok=True)
    skus = [p["sku_id"] for p in json.loads(Path("data/products/mvp_v1.json").read_text(encoding="utf-8"))]
    for s in skus:
        base = s[:-3] if s.endswith("_up") else s
        if base not in prod.SKUS:
            print("no picture for", s)
            continue
        icon(prod.OUT / ("%s_%d.png" % (base, SEED))).save(out / ("%s.png" % s))
        print(s)


if __name__ == "__main__":
    main()
