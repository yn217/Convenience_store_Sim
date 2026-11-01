import sys
from PIL import Image
name = sys.argv[1]
files = [f"renders/{name}_{s}.png" for s in ("front", "side", "yaw0", "yaw90", "yaw180", "yaw270")]
ims = [Image.open(f).convert("RGBA") for f in files]
h = 420
ims = [i.resize((max(1, int(i.width * h / i.height)), h)) for i in ims]
W = sum(i.width for i in ims) + 10 * len(ims)
s = Image.new("RGBA", (W, h), (205, 200, 190, 255))
x = 0
for i in ims:
    s.alpha_composite(i, (x, 0))
    x += i.width + 10
s.convert("RGB").save(f"renders/{name}_sheet.png")
