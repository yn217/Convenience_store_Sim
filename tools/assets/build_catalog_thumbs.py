"""Cuts the catalog photos (tools/assets/comfy_catalog.py) out of their white background into the build catalog's
thumbnails: 192x128 (BuildCatalog.THUMB_PIXELS, 2x the 100x70 drawn size), centred, transparent.

    python tools/assets/build_catalog_thumbs.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import build_chibi_sprites as chibi  # noqa: E402  (its cut(): white background flood fill)
import comfy_catalog as cat  # noqa: E402

SIZE = (192, 128)
SEED = 8101


def main() -> None:
    out = Path("assets/ui/catalog")
    out.mkdir(parents=True, exist_ok=True)
    for t in cat.TYPES:
        fig = chibi.cut(cat.OUT / ("%s_%d.png" % (t, SEED)))
        k = min((SIZE[0] - 4) / fig.width, (SIZE[1] - 4) / fig.height)
        small = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
        canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(small, ((SIZE[0] - small.width) // 2, (SIZE[1] - small.height) // 2))
        canvas.save(out / ("%s.png" % t))
        print(t)


if __name__ == "__main__":
    main()
