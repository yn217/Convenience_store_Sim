"""Build a visual-only 0.5x/1x/2x customer source-canvas preview."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/characters/candidates/source_1024"
OUT = ROOT / "docs/art/customer_zoom_review.png"

def main() -> None:
    paths = sorted(SOURCE.glob("*_source1024_v01.png"))
    cell_w, cell_h = 340, 520
    sheet = Image.new("RGBA", (cell_w * len(paths), cell_h * 3), (239, 238, 234, 255))
    draw = ImageDraw.Draw(sheet)
    for col, path in enumerate(paths):
        with Image.open(path).convert("RGBA") as source:
            for row, (scale, label) in enumerate(((0.5, "0.5x"), (1.0, "1x"), (2.0, "2x"))):
                image = source.resize((round(source.width * scale), round(source.height * scale)), Image.Resampling.NEAREST)
                image.thumbnail((300, 460), Image.Resampling.NEAREST)
                x = col * cell_w + (cell_w - image.width) // 2
                y = row * cell_h + 28 + (460 - image.height) // 2
                sheet.alpha_composite(image, (x, y))
                draw.text((col * cell_w + 10, row * cell_h + 8), f"{path.stem[:22]} | {label}", fill=(25, 25, 25, 255))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}: {sheet.width}x{sheet.height}")

if __name__ == "__main__":
    main()
