from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2] / "assets/source/textures/fixtures/inventory_states"
fixtures = [("shelf_general", "composite"), ("fridge_drink", ""), ("shelf_noodle", "")]
states = ("full", "half", "empty")
sheet = Image.new("RGB", (3 * 300, 3 * 300), "#20242a")
draw = ImageDraw.Draw(sheet)
for row, (fixture, suffix) in enumerate(fixtures):
    draw.text((row * 300 + 8, 6), fixture, fill="white")
    for col, state in enumerate(states):
        path = ROOT / fixture / f"{fixture}_{state}_r0{'_' + suffix if suffix else ''}.png"
        with Image.open(path).convert("RGBA") as image:
            image.thumbnail((260, 260))
            x = row * 300 + (300 - image.width) // 2
            y = col * 300 + 25 + (260 - image.height) // 2
            sheet.paste(image, (x, y), image)
        draw.text((row * 300 + 8, col * 300 + 278), state.upper(), fill="#d8dee9")
out = ROOT / "issue_91_contact_sheet_r0.png"
sheet.save(out)
print(out)
