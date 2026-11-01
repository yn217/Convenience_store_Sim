"""Build a shared-scale 3-fixture x 3-stock-state comparison sheet for Issue #91."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = (
    ("shelf_general", "GENERAL SHELF"),
    ("fridge_drink", "DRINK COOLER"),
    ("shelf_noodle", "CUP-NOODLE SHELF"),
)
STATES = ("FULL", "HALF", "EMPTY")
PITCH_X, PITCH_Y = 600, 620
BASELINE_OFFSET_Y = 420
MARGIN = 20


def main():
    width = MARGIN * 2 + PITCH_X * len(FIXTURES)
    height = MARGIN * 2 + PITCH_Y * len(STATES)
    sheet = Image.new("RGBA", (width, height), (231, 234, 237, 255))
    draw = ImageDraw.Draw(sheet)
    for column, (fixture, label) in enumerate(FIXTURES):
        candidate = ROOT / "assets" / "source" / "textures" / "fixtures" / "inventory_state_candidates" / (fixture + "_blender_v1")
        manifest = json.loads((candidate / "manifest.json").read_text(encoding="utf-8"))
        for row, state in enumerate(STATES):
            record = manifest["states"][state]["rotations"]["0"]
            sprite_path = candidate / record["layers"]["composite"]
            with Image.open(sprite_path).convert("RGBA") as sprite:
                anchor_x, anchor_y = record["anchor_px"]
                col_left = MARGIN + column * PITCH_X
                row_top = MARGIN + row * PITCH_Y
                x = round(col_left + PITCH_X * 0.5 - anchor_x)
                y = round(row_top + BASELINE_OFFSET_Y - anchor_y)
                sheet.alpha_composite(sprite, (x, y))
            draw.text((MARGIN + column * PITCH_X + 12, MARGIN + row * PITCH_Y + 8), label + " / " + state, fill=(24, 34, 45, 255))
            draw.line((col_left, row_top + BASELINE_OFFSET_Y, col_left + PITCH_X, row_top + BASELINE_OFFSET_Y), fill=(170, 178, 186, 255), width=1)
    output = ROOT / "assets" / "source" / "textures" / "fixtures" / "inventory_state_candidates" / "issue91_fixture_comparison_v01.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output, optimize=True)
    print("WROTE", output, sheet.size, "source-scale pixels; no sprite resizing")


if __name__ == "__main__":
    main()
