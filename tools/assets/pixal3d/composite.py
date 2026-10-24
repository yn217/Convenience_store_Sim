"""Paste iso2x renders onto a game screenshot at its zoom (sprite scale = zoom / 2), anchored on floor points."""
import json
from PIL import Image
ZOOM = 1.6
base = Image.open("renders/_game_z16.png").convert("RGBA")
items = [("S01_atm", 180, (1060, 330)), ("S02_multifunction_copier", 180, (1440, 300)),
         ("C00_hot_food_counter_combination", 180, (820, 520))]
for name, yaw, at in items:
    info = json.load(open(f"renders/{name}_info.json"))["renders"][str(yaw)]
    im = Image.open(info["png"]).convert("RGBA")
    ax, ay = info["anchor_px"]
    s = ZOOM / 2
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    base.alpha_composite(im, (round(at[0] - ax * s), round(at[1] - ay * s)))
base.convert("RGB").save("renders/_composite_z16.png")
