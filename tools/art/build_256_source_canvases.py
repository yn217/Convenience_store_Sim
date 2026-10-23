"""Fit normalized package candidates into the repository's 256x256 source canvas."""
from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "assets/source/textures/packages/candidates"
OUTPUT = INPUT / "source_256"
CANVAS = 256
MAX_OBJECT = 224


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for source in sorted(INPUT.glob("*_cutout_v02.png")):
        with Image.open(source).convert("RGBA") as image:
            scale = min(MAX_OBJECT / image.width, MAX_OBJECT / image.height, 1.0)
            size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
            resized = image.resize(size, Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            x = (CANVAS - resized.width) // 2
            y = CANVAS - resized.height
            canvas.alpha_composite(resized, (x, y))
            output = OUTPUT / source.name.replace("_cutout_v02.png", "_source256_v01.png")
            canvas.save(output, format="PNG", optimize=False)
            records.append({"source": str(source.relative_to(ROOT)), "output": str(output.relative_to(ROOT)), "canvas_px": [CANVAS, CANVAS], "object_px": list(size), "anchor_px": [x + resized.width // 2, CANVAS]})
    (OUTPUT / "SOURCE_CANVAS_MANIFEST.json").write_text(json.dumps({"projection": "source staging only; not iso2x rendered", "canvas_px": [CANVAS, CANVAS], "max_object_px": MAX_OBJECT, "candidates": records}, indent=2) + "\n", encoding="utf-8")
    sheet = Image.new("RGB", (CANVAS * 3, (CANVAS + 28) * 2), "#d9dde0")
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, record in enumerate(records):
        with Image.open(ROOT / record["output"]).convert("RGBA") as image:
            x = (index % 3) * CANVAS
            y = (index // 3) * (CANVAS + 28)
            sheet.paste(image, (x, y), image)
            draw.rectangle((x, y + CANVAS, x + CANVAS, y + CANVAS + 28), fill="#20252b")
            draw.text((x + 5, y + CANVAS + 9), Path(record["output"]).stem, fill="#ffffff", font=font)
    sheet.save(ROOT / "docs/art/package_source_canvas_contact_sheet.png", format="PNG")
    print(f"built {len(records)} 256x256 source canvases")


if __name__ == "__main__":
    main()
