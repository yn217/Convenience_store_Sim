from pathlib import Path

from PIL import Image, ImageDraw


root = Path(__file__).parent
source = Image.open(root / "source_original.png").convert("RGBA")
canvas_size = (1800, 1800)
offset = ((canvas_size[0] - source.width) // 2, (canvas_size[1] - source.height) // 2)
padded = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
padded.alpha_composite(source, offset)
padded.save(root / "sprite_padded_review.png")

tile = 40
background = Image.new("RGB", canvas_size, (238, 238, 238))
draw = ImageDraw.Draw(background)
for y in range(0, canvas_size[1], tile):
    for x in range(0, canvas_size[0], tile):
        if (x // tile + y // tile) % 2:
            draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(198, 203, 210))
background.paste(padded, (0, 0), padded.getchannel("A"))
background.save(root / "preview_checkerboard.jpg", quality=94)
