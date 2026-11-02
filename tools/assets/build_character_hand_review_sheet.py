"""Build a read-only hand/boundary review sheet for selected pilot images.

The sheet compares the original RGB-on-white render with the BiRefNet-derived
RGBA image and a magnified hand/product crop. It never changes either image or
the character-pilot registry approval state.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "presentation" / "character_visuals_v1.json"
OUTPUT = ROOT / "build" / "character_pilot_hand_review_20261103.png"
SHEET_WIDTH = 1200
ROW_HEIGHT = 540
IMAGE_SIZE = (270, 405)
CROP_SIZE = (270, 270)
HAND_BOXES = {
    # (left, top, right, bottom) in source-image pixels.
    "event_after_work": (350, 500, 960, 930),
    "event_snack_buzz": (360, 590, 690, 930),
}


def _font(size: int):
    for path in (Path("C:/Windows/Fonts/meiryo.ttc"), Path("C:/Windows/Fonts/arial.ttf")):
        if path.is_file():
            try:
                return ImageFont.truetype(str(path), size)
            except OSError:
                pass
    return ImageFont.load_default()


def _checker(size: tuple[int, int]) -> Image.Image:
    tile = 18
    image = Image.new("RGB", size, "#d9e0e4")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill="#b9c5cb")
    return image


def _matte(rgba: Image.Image) -> Image.Image:
    canvas = _checker(rgba.size).convert("RGBA")
    return Image.alpha_composite(canvas, rgba).convert("RGB")


def _fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, "#f3f5f6")
    canvas.paste(copy, ((size[0] - copy.width) // 2, (size[1] - copy.height) // 2))
    return canvas


def build(output: Path = OUTPUT) -> Path:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    entries = {entry["id"]: entry for entry in registry["assets"]}
    font = _font(18)
    small = _font(14)
    sheet = Image.new("RGB", (SHEET_WIDTH, ROW_HEIGHT * len(HAND_BOXES)), "#18232b")
    draw = ImageDraw.Draw(sheet)

    for row, asset_id in enumerate(HAND_BOXES):
        entry = entries[asset_id]
        source = Image.open(ROOT / entry["derived_from"].removeprefix("res://")).convert("RGBA")
        derived = Image.open(ROOT / entry["runtime_path"].removeprefix("res://")).convert("RGBA")
        left, top, right, bottom = HAND_BOXES[asset_id]
        source_rgb = source.convert("RGB")
        derived_rgb = _matte(derived)
        crop_source = source_rgb.crop((left, top, right, bottom))
        crop_derived = derived_rgb.crop((left, top, right, bottom))
        y = row * ROW_HEIGHT
        draw.text((24, y + 16), f"{asset_id} — source / derived / hand crop", fill="#f4f0e7", font=font)
        for index, image in enumerate((_fit(source_rgb, IMAGE_SIZE), _fit(derived_rgb, IMAGE_SIZE), _fit(crop_source, CROP_SIZE), _fit(crop_derived, CROP_SIZE))):
            x = 24 + index * 290
            sheet.paste(image, (x, y + 58))
        draw.text((24, y + 474), "source", fill="#f4f0e7", font=small)
        draw.text((314, y + 474), "derived alpha on checker", fill="#f4f0e7", font=small)
        draw.text((604, y + 474), "hand crop source", fill="#f4f0e7", font=small)
        draw.text((894, y + 474), "hand crop derived", fill="#f4f0e7", font=small)
        source.close()
        derived.close()

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG")
    print(f"hand_review_sheet={output} size={sheet.width}x{sheet.height}")
    return output


if __name__ == "__main__":
    build()
