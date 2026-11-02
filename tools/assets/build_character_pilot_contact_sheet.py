"""Build a read-only contact sheet for the selected character-pilot runtime assets.

The sheet is a review aid only. It never rewrites source or runtime PNGs and it
does not change the registry approval state.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "presentation" / "character_visuals_v1.json"
DEFAULT_OUTPUT = ROOT / "build" / "character_pilot_runtime_contact_20261102.png"
DEFAULT_CORE_OUTPUT = ROOT / "build" / "character_pilot_core_contact_20261103.png"
CARD_WIDTH = 240
CARD_HEIGHT = 320
IMAGE_BOX = (12, 8, CARD_WIDTH - 12, 270)
COLUMNS = 5


def _font(size: int):
    candidates = [
        Path("C:/Windows/Fonts/meiryo.ttc"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.is_file():
            try:
                return ImageFont.truetype(str(candidate), size)
            except OSError:
                pass
    return ImageFont.load_default()


def _load_entries(core_only: bool = False) -> list[dict]:
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    entries = [entry for entry in registry["assets"] if entry.get("runtime_path")]
    if len(entries) != 50:
        raise ValueError(f"expected 50 runtime entries, found {len(entries)}")
    if core_only:
        core_ids = registry.get("core_pilot_ids", [])
        if len(core_ids) != 11 or len(set(core_ids)) != 11:
            raise ValueError("core_pilot_ids must contain 11 unique runtime entries")
        by_id = {entry["id"]: entry for entry in entries}
        if not set(core_ids).issubset(by_id):
            raise ValueError("core_pilot_ids contains an unknown runtime entry")
        entries = [by_id[asset_id] for asset_id in core_ids]
    return sorted(entries, key=lambda entry: (entry.get("kind", ""), entry.get("id", "")))


def _card(entry: dict, font) -> Image.Image:
    card = Image.new("RGB", (CARD_WIDTH, CARD_HEIGHT), "#1d2b35")
    runtime_path = ROOT / str(entry["runtime_path"]).removeprefix("res://")
    if not runtime_path.is_file():
        raise FileNotFoundError(runtime_path)
    with Image.open(runtime_path) as opened:
        image = opened.convert("RGBA")
    matte = Image.new("RGBA", image.size, "#1d2b35")
    preview = Image.alpha_composite(matte, image) if image.getchannel("A").getbbox() else image.convert("RGBA")
    preview = ImageOps.contain(preview.convert("RGB"), (IMAGE_BOX[2] - IMAGE_BOX[0], IMAGE_BOX[3] - IMAGE_BOX[1]))
    x = IMAGE_BOX[0] + (IMAGE_BOX[2] - IMAGE_BOX[0] - preview.width) // 2
    y = IMAGE_BOX[1] + (IMAGE_BOX[3] - IMAGE_BOX[1] - preview.height) // 2
    card.paste(preview, (x, y))
    draw = ImageDraw.Draw(card)
    label = f"{entry['id']} [{entry.get('kind', '')}]"
    draw.text((10, 278), label, fill="#f4f0e7", font=font)
    draw.text((10, 296), "approved=" + str(bool(entry.get("runtime_approved", False))), fill="#d7b978", font=font)
    return card


def build(output: Path, core_only: bool = False) -> Path:
    entries = _load_entries(core_only=core_only)
    font = _font(13)
    rows = (len(entries) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGB", (COLUMNS * CARD_WIDTH, rows * CARD_HEIGHT), "#101a21")
    for index, entry in enumerate(entries):
        x = (index % COLUMNS) * CARD_WIDTH
        y = (index // COLUMNS) * CARD_HEIGHT
        sheet.paste(_card(entry, font), (x, y))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG")
    print(f"contact_sheet={output} entries={len(entries)} size={sheet.size[0]}x{sheet.size[1]}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--core-only",
        action="store_true",
        help="build the 11-image core QA sheet named by registry.core_pilot_ids",
    )
    args = parser.parse_args()
    output = args.output
    if args.core_only and output == DEFAULT_OUTPUT:
        output = DEFAULT_CORE_OUTPUT
    build(output, core_only=args.core_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
