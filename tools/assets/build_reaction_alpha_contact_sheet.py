"""Build a dark-matte contact sheet for the 50 reaction alpha candidates.

The sheet is a read-only review artifact. It prefers the derived alpha PNG
when one exists and never changes the source candidate, placement table, or
runtime approval state.
"""

from __future__ import annotations

import csv
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.csv"
CANDIDATE_ROOT = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui"
DERIVED_ROOT = ROOT / "assets" / "review" / "derived_alpha"
DEFAULT_OUTPUT = ROOT / "docs" / "art" / "character_reaction_derived_alpha_contact_20261102.png"

COLS = 10
CELL_W = 190
CELL_H = 220
THUMB_W = 170
THUMB_H = 176


def _font(size: int):
    for path in (ROOT / "assets" / "fonts" / "MPLUSRounded1c-Bold.ttf", Path("C:/Windows/Fonts/meiryo.ttc")):
        if path.is_file():
            try:
                return ImageFont.truetype(str(path), size)
            except OSError:
                pass
    return ImageFont.load_default()


def _rows() -> list[dict[str, str]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        return [row for row in csv.DictReader(handle) if "reaction" in row["group"]]


def build(output: Path) -> None:
    rows = _rows()
    if len(rows) != 50:
        raise ValueError(f"expected 50 reaction rows, got {len(rows)}")

    height = ((len(rows) + COLS - 1) // COLS) * CELL_H
    sheet = Image.new("RGB", (COLS * CELL_W, height), (21, 24, 31))
    draw = ImageDraw.Draw(sheet)
    label_font = _font(15)
    status_font = _font(12)

    for index, row in enumerate(rows):
        x = (index % COLS) * CELL_W
        y = (index // COLS) * CELL_H
        draw.rectangle((x + 1, y + 1, x + CELL_W - 2, y + CELL_H - 2), fill=(42, 47, 60))
        asset_id = row["asset_id"]
        derived = DERIVED_ROOT / f"{asset_id}.png"
        source = CANDIDATE_ROOT / row["candidate_relpath"]
        path = derived if derived.is_file() else source
        with Image.open(path) as opened:
            image = opened.convert("RGBA")
            image.thumbnail((THUMB_W, THUMB_H), Image.Resampling.LANCZOS)
            matte = Image.new("RGB", image.size, (21, 24, 31))
            matte.paste(image, mask=image.getchannel("A"))
            sheet.paste(matte, (x + (CELL_W - matte.width) // 2, y + 6))
        draw.text((x + 8, y + CELL_H - 34), f"{index + 1:02d} {asset_id}", font=label_font, fill=(255, 255, 255))
        draw.text((x + 8, y + CELL_H - 17), "派生透過" if path == derived else "原画像", font=status_font, fill=(220, 224, 235))

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=True)
    derived_count = sum((DERIVED_ROOT / (row["asset_id"] + ".png")).is_file() for row in rows)
    print(f"contact_sheet={output} candidates={len(rows)} derived={derived_count} size={sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[2] / "docs" / "art" / "character_reaction_derived_alpha_contact_20261102.png")
