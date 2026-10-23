"""Build a compact before/after sheet for the POP cutout staging step."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "assets/source/textures/pop/candidates"
OUTPUT = ROOT / "docs/art/pop_cutout_before_after.png"


def checker(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGB", size, "#eef1f3")
    draw = ImageDraw.Draw(image)
    tile = 16
    for y in range(0, size[1], tile):
        for x in range(0, size[0], tile):
            if (x // tile + y // tile) % 2:
                draw.rectangle((x, y, x + tile, y + tile), fill="#d7dce0")
    return image.convert("RGBA")


def main() -> None:
    rows = []
    for variant in ("a", "b"):
        with Image.open(INPUT / f"shelf_pop_comparison_v01_{variant}.png").convert("RGBA") as before:
            with Image.open(INPUT / f"shelf_pop_comparison_v01_{variant}_cutout_v02.png").convert("RGBA") as after:
                rows.append((variant, before.copy(), after.copy()))
    cell_w, cell_h = 420, 470
    sheet = Image.new("RGB", (cell_w * 2, cell_h * len(rows)), "#20252b")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for row, (variant, before, after) in enumerate(rows):
        for col, (label, image, background) in enumerate((("before / studio background", before, Image.new("RGBA", (cell_w, cell_h), "#eef1f3")), ("after / transparent + contact", after, checker((cell_w, cell_h))))):
            image.thumbnail((cell_w - 20, cell_h - 45), Image.Resampling.LANCZOS)
            background.alpha_composite(image, ((cell_w - image.width) // 2, 28 + (cell_h - 45 - image.height) // 2))
            background.convert("RGB").save(OUTPUT.with_suffix(f".tmp_{row}_{col}.png"))
            sheet.paste(background.convert("RGB"), (col * cell_w, row * cell_h))
            draw.text((col * cell_w + 8, row * cell_h + 8), f"POP {variant} - {label}", fill="#ffffff", font=font)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT, format="PNG")
    for temporary in OUTPUT.parent.glob("pop_cutout_before_after.tmp_*.png"):
        temporary.unlink(missing_ok=True)
    print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
