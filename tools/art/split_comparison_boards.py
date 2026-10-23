"""Split generated two-panel comparison boards into reviewable candidate PNGs.

The source boards are intentionally kept unchanged. This deterministic crop is
only a staging step before human text/trademark review and iso2x rendering.
"""
from pathlib import Path
import json
import os

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
GROUPS = {
    "packages": [
        "sku_onigiri_comparison_v01",
        "sku_tea_comparison_v01",
        "sku_cupnoodle_comparison_v01",
    ],
    "materials": [
        "register_basic_material_comparison_v01",
        "shelf_general_material_comparison_v01",
        "fridge_drink_material_comparison_v01",
    ],
}


def split(stem: str, group: str) -> list[dict[str, object]]:
    source = ROOT / "assets/source/textures" / group / f"{stem}.png"
    out_dir = ROOT / "assets/source/textures" / group / "candidates"
    out_dir.mkdir(parents=True, exist_ok=True)
    records = []
    with Image.open(source) as image:
        image = image.convert("RGBA")
        width, height = image.size
        midpoint = width // 2
        # Keep a narrow seam margin out of both candidates; no resampling.
        boxes = {
            "a": (0, 0, midpoint - 8, height),
            "b": (midpoint + 8, 0, width, height),
        }
        for variant, box in boxes.items():
            output = out_dir / f"{stem}_{variant}.png"
            temporary = output.with_suffix(".tmp.png")
            image.crop(box).save(temporary, format="PNG", optimize=False)
            os.replace(temporary, output)
            records.append({"source": str(source.relative_to(ROOT)), "variant": variant, "file": str(output.relative_to(ROOT)), "crop_box": list(box), "size": [box[2] - box[0], box[3] - box[1]]})
    return records


def main() -> None:
    records = []
    for group, stems in GROUPS.items():
        for stem in stems:
            records.extend(split(stem, group))
    manifest = ROOT / "assets/source/textures/CANDIDATE_CROPS.json"
    manifest.write_text(json.dumps({"method": "Pillow lossless RGBA crop", "seam_margin_px": 8, "candidates": records}, indent=2) + "\n", encoding="utf-8")
    thumbs = []
    for record in records:
        path = ROOT / record["file"]
        with Image.open(path) as image:
            thumb = image.copy()
            thumb.thumbnail((240, 240), Image.Resampling.LANCZOS)
        thumbs.append((Path(record["file"]).name, thumb))
    sheet = Image.new("RGB", (240 * 4, 280 * ((len(thumbs) + 3) // 4)), "#eef1f3")
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (name, thumb) in enumerate(thumbs):
        x = (index % 4) * 240
        y = (index // 4) * 280
        sheet.paste(thumb.convert("RGB"), (x + (240 - thumb.width) // 2, y))
        draw.rectangle((x, y + 240, x + 240, y + 280), fill="#20252b")
        draw.text((x + 6, y + 14), name, fill="#ffffff", font=font)
    sheet_output = ROOT / "docs/art/package_material_individual_candidates.png"
    sheet_temporary = sheet_output.with_suffix(".tmp.png")
    sheet.save(sheet_temporary, format="PNG", optimize=False)
    os.replace(sheet_temporary, sheet_output)
    print(f"cropped {len(records)} candidates")


if __name__ == "__main__":
    main()
