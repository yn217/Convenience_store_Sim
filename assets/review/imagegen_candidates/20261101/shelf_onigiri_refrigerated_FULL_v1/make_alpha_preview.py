from pathlib import Path

from PIL import Image, ImageDraw


root = Path(__file__).parent
source = Image.open(root / "source_original.png").convert("RGBA")
width, height = source.size
tile = 32
background = Image.new("RGB", source.size, (238, 238, 238))
draw = ImageDraw.Draw(background)
for y in range(0, height, tile):
    for x in range(0, width, tile):
        if (x // tile + y // tile) % 2:
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(198, 203, 210))
background.paste(source, (0, 0), source.getchannel("A"))
background.save(root / "alpha_preview.png")
