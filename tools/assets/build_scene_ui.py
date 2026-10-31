"""Scales the chosen scene renders (tools/assets/comfy_scenes.py) to the size the game draws them:

    title background   full screen       -> assets/ui/title/title_background.png   1920x1080 (cover crop)
    event illustration 384x216 in a card -> assets/ui/events/<event_id>.png        576x324 (1.5x)

    python tools/assets/build_scene_ui.py
"""
from pathlib import Path

from PIL import Image, ImageFilter

SRC = Path("assets/source/scenes")
TITLE_PICK = 5101
EVENT_PICK = 5101
EVENTS = ["evt_local_fair", "evt_roadworks", "evt_hot_day", "evt_cold_day", "evt_sweets_spotlight", "evt_snack_buzz",
          "evt_neighbor_mentions", "evt_quiet_street", "evt_lunch_pick", "evt_drink_pick", "evt_bread_feature", "evt_after_work"]
TITLE = (1920, 1080)
EVENT = (576, 324)


def cover(im: Image.Image, size: tuple) -> Image.Image:
    w, h = im.size
    k = max(size[0] / w, size[1] / h)
    big = im.resize((round(w * k), round(h * k)), Image.LANCZOS)
    left = (big.width - size[0]) // 2
    top = (big.height - size[1]) // 2
    return big.crop((left, top, left + size[0], top + size[1]))


def main() -> None:
    Path("assets/ui/events").mkdir(parents=True, exist_ok=True)
    title = cover(Image.open(SRC / ("title_%d.png" % TITLE_PICK)).convert("RGB"), TITLE)
    title = title.filter(ImageFilter.UnsharpMask(radius=1.2, percent=40, threshold=2))   # the 1.43x upscale, crisped a little
    title.save("assets/ui/title/title_background.png")
    print("title", title.size)
    for e in EVENTS:
        cover(Image.open(SRC / ("%s_%d.png" % (e, EVENT_PICK))).convert("RGB"), EVENT).save("assets/ui/events/%s.png" % e)
        print("event", e)


MEDIA = ["newspaper", "radio", "web_ads", "television"]
MEDIA_PICK = 7101
MEDIA_SIZE = (192, 108)   # the 媒体広告 thumbnail slot is 128x72


def media() -> None:
    Path("assets/ui/media").mkdir(parents=True, exist_ok=True)
    for m in MEDIA:
        cover(Image.open(Path("assets/source/media") / ("%s_%d.png" % (m, MEDIA_PICK))).convert("RGB"), MEDIA_SIZE).save("assets/ui/media/%s.png" % m)
        print("media", m)


PROMOS = ["fair_autumn", "fair_winter", "fair_summer", "fair_regional", "collab_mascot", "gift_clearfile", "gift_sticker", "stamps_lunch"]


def promos() -> None:
    Path("assets/ui/promotions").mkdir(parents=True, exist_ok=True)
    for p in PROMOS:
        cover(Image.open(Path("assets/source/promotions") / ("%s_%d.png" % (p, MEDIA_PICK))).convert("RGB"), MEDIA_SIZE).save("assets/ui/promotions/%s.png" % p)
        print("promo", p)


if __name__ == "__main__":
    import sys
    if "--promos" in sys.argv:
        promos()
    elif "--media" in sys.argv:
        media()
    else:
        main()
