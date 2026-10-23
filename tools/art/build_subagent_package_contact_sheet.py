from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs" / "art" / "subagent_package_candidate_contact_sheet_v02.png"
ITEMS = [
    ("Bento / salmon", ROOT / "assets/source/textures/packages/bento_orange_salmon_subagent_v01.png"),
    ("Bento / chicken", ROOT / "assets/source/textures/packages/bento_teal_chicken_subagent_v01.png"),
    ("Sandwich / chicken", ROOT / "assets/source/textures/packages/sandwich_chicken_coral_subagent_v02.png"),
    ("Deli bread / egg", ROOT / "assets/source/textures/packages/deli_bread_teal_subagent_v01.png"),
    ("Onigiri / kombu", ROOT / "assets/source/textures/packages/onigiri_kombu_cool_subagent_v02.png"),
    ("Cup noodle / warm", ROOT / "assets/source/textures/packages/cupnoodle_warm_subagent_v01.png"),
    ("Drink / citrus", ROOT / "assets/source/textures/packages/drink_citrus_soda_subagent_v01.png"),
    ("Drink / berry tea", ROOT / "assets/source/textures/packages/drink_berry_tea_subagent_v01.png"),
    ("Dairy / mint", ROOT / "assets/source/textures/packages/dairy_cup_mint_subagent_v01.png"),
    ("Candy / warm", ROOT / "assets/source/textures/packages/candy_pouch_warm_subagent_v01.png"),
    ("Ice cream / blueberry", ROOT / "assets/source/textures/packages/icecream_blueberry_yogurt_subagent_v01.png"),
    ("Hot coffee / white", ROOT / "assets/source/textures/packages/hot_coffee_white_brown_subagent_v01.png"),
    ("Green tea / jade", ROOT / "assets/source/textures/packages/green_tea_jade_subagent_v01.png"),
    ("Strawberry milk / pink", ROOT / "assets/source/textures/packages/strawberry_milk_pink_subagent_v01.png"),
    ("Curry bread / warm", ROOT / "assets/source/textures/packages/curry_bread_warm_subagent_v01.png"),
    ("Fruit jelly / pink", ROOT / "assets/source/textures/packages/fruit_jelly_pink_subagent_v01.png"),
    ("Tuna sandwich / cool", ROOT / "assets/source/textures/packages/sandwich_tuna_cool_subagent_v01.png"),
    ("Egg sandwich / warm", ROOT / "assets/source/textures/packages/sandwich_egg_warm_subagent_v01.png"),
    ("Custard pudding / yellow", ROOT / "assets/source/textures/packages/custard_pudding_yellow_subagent_v01.png"),
    ("Blueberry ice cream / lavender", ROOT / "assets/source/textures/packages/blueberry_icecream_lavender_subagent_v01.png"),
    ("Seaweed chips / coral", ROOT / "assets/source/textures/packages/seaweed_chips_coral_subagent_v01.png"),
    ("Soy crackers / teal", ROOT / "assets/source/textures/packages/butter_soy_crackers_teal_subagent_v01.png"),
    ("Spicy miso cup noodle", ROOT / "assets/source/textures/packages/cupnoodle_spicy_miso_subagent_v01.png"),
    ("Seafood salt cup noodle", ROOT / "assets/source/textures/packages/cupnoodle_seafood_salt_subagent_v01.png"),
]


def make_sheet() -> None:
    thumb_w, thumb_h, label_h = 320, 320, 36
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
        px = x + (thumb_w - image.width) // 2
        py = y + (thumb_h - image.height) // 2
        sheet.paste(image, (px, py))
        draw.rectangle((x, y + thumb_h, x + thumb_w, y + thumb_h + label_h), fill="#20252b")
        draw.text((x + 8, y + thumb_h + 12), label, fill="#ffffff", font=font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT, format="PNG", optimize=True)


if __name__ == "__main__":
    make_sheet()
