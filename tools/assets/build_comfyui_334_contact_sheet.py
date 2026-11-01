"""Build a read-only review contact sheet for Issue #230's 334 candidates.

The source PNGs and the placement table are never modified.  The sheet is a
review aid only; it does not change approval or runtime registry state.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.csv"
CANDIDATE_ROOT = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui"
DEFAULT_OUTPUT = ROOT / "docs" / "art" / "COMFYUI_334_CONTACT_SHEET_20261103.png"

COLS = 12
CELL_W = 180
CELL_H = 224
THUMB_W = 164
THUMB_H = 184
PAD = 10


def _font(size: int):
    candidates = [
        ROOT / "assets" / "fonts" / "MPLUSRounded1c-Bold.ttf",
        Path("C:/Windows/Fonts/meiryo.ttc"),
    ]
    for path in candidates:
        if path.is_file():
            try:
                return ImageFont.truetype(str(path), size)
            except OSError:
                pass
    return ImageFont.load_default()


def _group_color(group: str) -> tuple[int, int, int]:
    if "reaction" in group:
        return (76, 56, 100)
    if "title" in group:
        return (112, 76, 36)
    if "additional" in group:
        return (40, 91, 99)
    if "functional" in group:
        return (43, 76, 112)
    return (48, 92, 67)


def _read_rows() -> list[dict[str, str]]:
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def build(output: Path) -> None:
    rows = _read_rows()
    if len(rows) != 334:
        raise ValueError(f"expected 334 placement rows, got {len(rows)}")

    rows_count = (len(rows) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * CELL_W, rows_count * CELL_H), (26, 29, 36))
    draw = ImageDraw.Draw(sheet)
    label_font = _font(16)
    trigger_font = _font(13)

    for index, row in enumerate(rows):
        x = (index % COLS) * CELL_W
        y = (index // COLS) * CELL_H
        group = row["group"]
        draw.rectangle((x + 1, y + 1, x + CELL_W - 2, y + CELL_H - 2), fill=_group_color(group))
        source = CANDIDATE_ROOT / row["candidate_relpath"]
        with Image.open(source) as source_image:
            image = source_image.convert("RGBA")
            image.thumbnail((THUMB_W, THUMB_H), Image.Resampling.LANCZOS)
            px = x + (CELL_W - image.width) // 2
            py = y + PAD
            sheet.paste(image, (px, py), image if image.getbbox() else None)

        label = f"{index + 1:03d} {row['asset_id']}"
        draw.text((x + PAD, y + CELL_H - 36), label, font=label_font, fill=(255, 255, 255))
        trigger = row["trigger_id"]
        if len(trigger) > 22:
            trigger = trigger[:21] + "…"
        draw.text((x + PAD, y + CELL_H - 17), trigger, font=trigger_font, fill=(238, 229, 196))

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=True)
    print(f"contact_sheet={output} candidates={len(rows)} size={sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    build(Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_OUTPUT)
