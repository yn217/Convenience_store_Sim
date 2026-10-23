from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art" / "package_material_candidate_contact_sheet.png"
ITEMS = [
    ("SKU / onigiri / 2 concepts", ROOT / "assets/source/textures/packages/sku_onigiri_comparison_v01.png"),
    ("SKU / tea / 2 concepts", ROOT / "assets/source/textures/packages/sku_tea_comparison_v01.png"),
    ("SKU / cup noodle / 2 concepts", ROOT / "assets/source/textures/packages/sku_cupnoodle_comparison_v01.png"),
    ("Fixture / register_basic / 2 materials", ROOT / "assets/source/textures/materials/register_basic_material_comparison_v01.png"),
    ("Fixture / shelf_general / 2 materials", ROOT / "assets/source/textures/materials/shelf_general_material_comparison_v01.png"),
    ("Fixture / fridge_drink / 2 materials", ROOT / "assets/source/textures/materials/fridge_drink_material_comparison_v01.png"),
]


def make_sheet() -> None:
    thumb_w, thumb_h = 480, 480
    label_h = 48
    sheet = Image.new("RGB", (thumb_w * 3, (thumb_h + label_h) * 2), "#eef1f3")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (label, path) in enumerate(ITEMS):
        image = Image.open(path).convert("RGB")
        image.thumbnail((thumb_w - 16, thumb_h - 16), Image.Resampling.LANCZOS)
        x = (index % 3) * thumb_w
        y = (index // 3) * (thumb_h + label_h)
        px = x + (thumb_w - image.width) // 2
        py = y + (thumb_h - image.height) // 2
        sheet.paste(image, (px, py))
        draw.rectangle((x, y + thumb_h, x + thumb_w, y + thumb_h + label_h), fill="#20252b")
        draw.text((x + 10, y + thumb_h + 17), label, fill="#ffffff", font=font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, format="PNG", optimize=True)


if __name__ == "__main__":
    make_sheet()
