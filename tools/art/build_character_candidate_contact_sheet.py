"""Build a review-only contact sheet for character/action candidates."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art" / "subagent_character_candidate_contact_sheet_v01.png"
BASE = ROOT / "assets/source/textures/characters/candidates"
ITEMS = [
    ("Customer / casual", BASE / "customer_casual_adult_beige_tote_imagegen_v01.png"),
    ("Customer / student", BASE / "customer_student_navy_backpack_imagegen_v01.png"),
    ("Clerk / cashier", BASE / "clerk_cashier_teal_apron_imagegen_v01.png"),
    ("Clerk / restock", BASE / "clerk_restock_orange_apron_imagegen_v01.png"),
    ("Action / reach clean", BASE / "customer_reaching_shelf_clean_imagegen_v01.png"),
    ("Action / basket clean", BASE / "customer_basket_shelf_clean_imagegen_v01.png"),
    ("Action / bag clean", BASE / "clerk_paper_bag_clean_imagegen_v01.png"),
    ("Action / box clean", BASE / "clerk_cardboard_box_clean_imagegen_v01.png"),
]

def main() -> None:
    thumb_w, thumb_h, label_h = 320, 420, 36
    cols = 4
    rows = (len(ITEMS) + cols - 1) // cols
    sheet = Image.new("RGB", (thumb_w * cols, (thumb_h + label_h) * rows), "#eef1f3")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for index, (label, path) in enumerate(ITEMS):
        image = Image.open(path).convert("RGBA")
        background = Image.new("RGBA", image.size, (245, 246, 247, 255))
        background.alpha_composite(image)
        image = background.convert("RGB")
        image.thumbnail((thumb_w - 20, thumb_h - 20), Image.Resampling.LANCZOS)
        x = (index % cols) * thumb_w
        y = (index // cols) * (thumb_h + label_h)
        sheet.paste(image, (x + (thumb_w - image.width) // 2, y + (thumb_h - image.height) // 2))
        draw.rectangle((x, y + thumb_h, x + thumb_w, y + thumb_h + label_h), fill="#20252b")
        draw.text((x + 8, y + thumb_h + 12), label, fill="#ffffff", font=font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, format="PNG", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({len(ITEMS)} candidates)")

if __name__ == "__main__":
    main()
