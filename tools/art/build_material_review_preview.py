"""Build a baseline fixture material A/B and zoom review sheet."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PROV = ROOT / "assets/source/textures/materials/MATERIAL_PROVENANCE.json"
OUT = ROOT / "docs/art/material_candidate_zoom_review.png"

def main() -> None:
    data = json.loads(PROV.read_text(encoding="utf-8"))
    cell_w, cell_h = 360, 460
    sheet = Image.new("RGB", (cell_w * len(data["fixtures"]), cell_h * 2), (238, 237, 233))
    draw = ImageDraw.Draw(sheet)
    for col, fixture in enumerate(data["fixtures"]):
        x = col * cell_w
        draw.text((x + 10, 8), fixture["fixture_type_id"], fill=(25, 25, 25))
        for row, path in enumerate(fixture["variants"]):
            with Image.open(ROOT / path).convert("RGBA") as image:
                image.thumbnail((330, 300), Image.Resampling.LANCZOS)
                px = x + (cell_w - image.width) // 2
                py = row * cell_h + 35
                sheet.paste(image, (px, py), image)
                draw.text((x + 10, row * cell_h + 340), f"variant {chr(65 + row)} | 1x", fill=(25, 25, 25))
                for scale, label in ((0.5, "0.5x"), (2.0, "2x")):
                    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
                    preview = image.resize(size, Image.Resampling.NEAREST)
                    preview.thumbnail((90, 70), Image.Resampling.NEAREST)
                    sheet.paste(preview, (x + 110 + int(scale * 40), row * cell_h + 365), preview)
                draw.text((x + 10, row * cell_h + 430), "review only; material + scale check", fill=(90, 90, 90))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}: {sheet.width}x{sheet.height}")

if __name__ == "__main__":
    main()
