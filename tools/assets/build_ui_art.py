"""Cuts the chosen UI pictures (tools/assets/comfy_ui_art.py renders on white) out to assets/ui/art/<name>.png, 128 px
on the long side (2x the largest size the UI draws them at), centred on a square transparent canvas.

    python tools/assets/build_ui_art.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import build_chibi_sprites as chibi  # noqa: E402  (its cut(): white background flood fill)

SRC = Path("assets/source/ui_art")
OUT = Path("assets/ui/art")
SIZE = 128
# picture name -> the render picked by eye (seed 9401: glossy icon prompt, 9402: sticker prompt)
PICKS = {
    "coins": "coins_9401", "arrow_up": "arrow_up_9401", "bell": "bell_9401", "basket": "basket_9401",
    "clipboard": "clipboard_9401", "mission": "mission_9402", "book": "book_9402", "calendar": "calendar_9402",
    "flag": "flag_9402", "sakura": "sakura_9401", "trophy": "nav_achievement_9401", "store_building": "store_building_9401",
    "logo_store": "logo_store_9401", "box": "nav_goods_9401", "cart": "cart_9401",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, src in PICKS.items():
        fig = chibi.cut(SRC / (src + ".png"))
        fig = fig.crop(fig.getbbox())
        k = (SIZE - 4) / max(fig.width, fig.height)
        small = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
        canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        canvas.alpha_composite(small, ((SIZE - small.width) // 2, (SIZE - small.height) // 2))
        canvas.save(OUT / (name + ".png"))
    print(len(PICKS), "pictures")
    # 小春六花 beside the window: cut from the mockup with Idol's BiRefNet (tools/assets/idol/cutout.py), at the mockup's
    # size on the 1920x1080 screen (MockupChrome.RIKKA_RECT)
    cut = Image.open("assets/source/ui_mockup/rikka_cut.png").convert("RGBA")
    k = 1920 / 1672
    Path("assets/ui/mockup").mkdir(parents=True, exist_ok=True)
    cut.resize((round(cut.width * k), round(cut.height * k)), Image.LANCZOS).save("assets/ui/mockup/rikka.png")


if __name__ == "__main__":
    main()
