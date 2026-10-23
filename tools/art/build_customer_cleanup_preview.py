"""Build a review-only before/after sheet for the casual alpha cleanup."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BEFORE = ROOT / "assets/source/textures/characters/candidates/source_1024/customer_casual_tote_cutout_source1024_v01.png"
AFTER = ROOT / "assets/source/textures/characters/candidates/source_1024/customer_casual_tote_cutout_cleaned_v01.png"
OUT = ROOT / "docs/art/customer_cleanup_before_after.png"

def main() -> None:
    sheet = Image.new("RGB", (820, 820), (210, 210, 210))
    draw = ImageDraw.Draw(sheet)
    for index, (label, path) in enumerate((("before", BEFORE), ("alpha<16 cleanup", AFTER))):
        with Image.open(path).convert("RGBA") as image:
            image.thumbnail((390, 760), Image.Resampling.NEAREST)
            x = index * 410 + (410 - image.width) // 2
            y = 35 + (760 - image.height) // 2
            sheet.paste(image, (x, y), image)
            draw.text((index * 410 + 12, 10), label, fill=(20, 20, 20))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}: {sheet.width}x{sheet.height}")

if __name__ == "__main__":
    main()
