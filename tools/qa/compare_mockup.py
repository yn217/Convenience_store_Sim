"""Side-by-side check of the game UI against the 2026-11-01 mockup, part by part: each part is cut from the mockup
(scaled to 1920x1080) and from a game capture at the same rect, mockup on top, game below, enlarged.

    python tools/qa/compare_mockup.py <capture.png> <goods|data> <out_dir>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

PARTS = {
    "common": {
        "top_left": (0, 0, 960, 70),
        "top_right": (930, 0, 1920, 70),
        "menu": (0, 120, 250, 700),
        "bubble": (0, 690, 400, 910),
        "bottom_left": (0, 915, 1050, 1080),
        "bottom_right": (1040, 915, 1920, 1080),
        "window_head": (520, 200, 1630, 390),
    },
    "goods": {
        "order_card": (550, 385, 1600, 545),
        "price_head": (550, 545, 1600, 620),
        "price_rows": (550, 600, 1600, 880),
    },
    "data": {
        "report": (550, 385, 1600, 560),
        "chart": (550, 555, 1600, 740),
        "ranking": (550, 735, 1600, 880),
    },
}


def main() -> None:
    cap = Image.open(sys.argv[1]).convert("RGB").resize((1920, 1080))
    tab = sys.argv[2]
    out = Path(sys.argv[3])
    out.mkdir(parents=True, exist_ok=True)
    mock = Image.open("docs/mockups/ui_target_%s_2026-11-01.png" % tab).convert("RGB").resize((1920, 1080), Image.LANCZOS)
    for name, box in {**PARTS["common"], **PARTS[tab]}.items():
        a, b = mock.crop(box), cap.crop(box)
        k = min(2.0, 1500 / a.width)
        size = (round(a.width * k), round(a.height * k))
        sheet = Image.new("RGB", (size[0], size[1] * 2 + 24), "white")
        sheet.paste(a.resize(size, Image.LANCZOS), (0, 0))
        sheet.paste(b.resize(size, Image.LANCZOS), (0, size[1] + 24))
        d = ImageDraw.Draw(sheet)
        d.text((4, size[1] + 4), "above: mockup / below: game  " + name, fill=(200, 0, 0))
        sheet.save(out / ("%s_%s.png" % (tab, name)))


if __name__ == "__main__":
    main()
