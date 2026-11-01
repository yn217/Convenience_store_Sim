"""Turns the chosen ComfyUI renders into the game's character images, at the size the game draws them (about 1.5x the
on-screen size at the 1920x1080 base resolution, so they stay sharp in a larger window without wasting memory):

    小春六花 corner figure  300x436 on screen -> assets/ui/characters/rikka_<mood>.png   450x654
    title screen figure     ~ 640 tall        -> assets/ui/title/title_rikka.png           640x931
    portraits (panels)       96x96 on screen  -> assets/ui/portraits/<id>.png               144x144, round

    python tools/assets/build_character_ui.py
"""
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RIKKA = Path("assets/source/characters/koharu_rikka/generated")
PORTRAITS = Path("assets/source/characters/portraits")
# The renders picked by eye (see docs/ASSET_CREDITS.md): seeds per mood / person.
RIKKA_PICKS = {"normal": 3103, "happy": 3201, "worried": 3101, "point": 3201, "welcome": 3201}
PORTRAIT_PICKS = {"customer_a": 4101, "customer_b": 4101, "customer_c": 4101, "staff_1": 4101, "staff_2": 4101, "staff_3": 4101, "staff_4": 4101,
                  "office_worker": 4101, "student": 4101, "parent": 4101,
                  "elderly_woman": 4101}
FIGURE = (450, 654)
PORTRAIT = 144


def cutout(src: Path) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        dst = Path(tmp) / "cut.png"
        subprocess.run([sys.executable, "tools/assets/cutout_rikka_stand.py", str(src), str(dst)], check=True, capture_output=True)
        return Image.open(dst).copy()


def portrait(src: Path) -> Image.Image:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    side = int(w * 0.78)   # head and shoulders: a centred square from near the top
    left = (w - side) // 2
    top = int(h * 0.04)
    face = im.crop((left, top, left + side, top + side)).resize((PORTRAIT, PORTRAIT), Image.LANCZOS)
    big = PORTRAIT * 4
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, big - 3, big - 3), fill=255)
    mask = mask.resize((PORTRAIT, PORTRAIT), Image.LANCZOS)
    out = face.convert("RGBA")
    out.putalpha(mask)
    return out


def main() -> None:
    Path("assets/ui/characters").mkdir(parents=True, exist_ok=True)
    Path("assets/ui/title").mkdir(parents=True, exist_ok=True)
    Path("assets/ui/portraits").mkdir(parents=True, exist_ok=True)
    for mood, seed in RIKKA_PICKS.items():
        cut = cutout(RIKKA / ("rikka_%s_%d.png" % (mood, seed)))
        if mood == "welcome":
            cut.save("assets/ui/title/title_rikka.png")
        cut.resize(FIGURE, Image.LANCZOS).save("assets/ui/characters/rikka_%s.png" % mood)
        print("rikka", mood, cut.size, "->", FIGURE)
    for pid, seed in PORTRAIT_PICKS.items():
        portrait(PORTRAITS / ("%s_%d.png" % (pid, seed))).save("assets/ui/portraits/%s.png" % pid)
        print("portrait", pid)


if __name__ == "__main__":
    main()
