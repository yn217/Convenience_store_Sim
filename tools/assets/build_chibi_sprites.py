"""Builds the in-store people's sprite sets from the chibi renders (tools/assets/comfy_chibi.py), in the layout the game
already reads (CustomerSprites, *.character.json): canvas 190x329 with the feet at (95, 282), facings d0..d3 = E, S,
W, N (screen down-right, down-left, up-left, up-right). The renders face left, so:
    d1 (down-left)  = front view          d0 (down-right) = front view mirrored
    d2 (up-left)    = back view           d3 (up-right)   = back view mirrored
Walking, idling and inspecting are the same drawing, stretched a few px taller and back with the feet planted (the
renders are single poses; the feet stay on the anchor row in every frame, as tools/assets/validate_customers.py wants).

    python tools/assets/build_chibi_sprites.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage

SRC = Path("assets/source/characters/chibi")
DST = Path("assets/generated/characters")
PICKS = {"customer_a": 6101, "customer_b": 6101, "customer_c": 6101, "clerk": 6101,
         "office_worker": 6101, "student": 6101, "parent": 6101,
         "staff_1": 6101, "staff_2": 6101, "staff_3": 6101, "staff_4": 6101}   # staff wear the look of their face
CANVAS = (190, 329)
FEET = (95, 282)
HEIGHT = 262          # the figure's height on the canvas (the box figures were about as tall)
BOBS = {"walk": [0, 4, 6, 4, 0, 2], "idle": [0, 2], "inspect": [0, 3, 4, 3]}   # extra height in px per frame
FEET_DROP = 3   # the soles sit a little below the anchor row, inside the tile, like the box figures' feet


def cut(path: Path) -> Image.Image:
    im = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    mn, mx = im.min(axis=2), im.max(axis=2)
    bg = (mn >= 235) & ((mx - mn) <= 14)
    lab, _ = ndimage.label(bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    mask = np.isin(lab, list(border))
    alpha = ndimage.gaussian_filter(np.where(mask, 0.0, 1.0), 0.6)
    rgba = np.dstack([im.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    out = Image.fromarray(rgba, "RGBA")
    return out.crop(out.getbbox())


def scale_of(fig: Image.Image) -> float:
    k = HEIGHT / fig.height
    return min(k, (CANVAS[0] - 4) / fig.width)


## `k`: the standing figure's scale, used for every pose of a person so the size never jumps between frames.
def place(fig: Image.Image, stretch: int, k: float) -> Image.Image:
    w = min(round(fig.width * k), CANVAS[0] - 4)
    h = round(fig.height * k)
    small = fig.resize((w, h + stretch), Image.LANCZOS)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(small, (FEET[0] - w // 2, FEET[1] + FEET_DROP - (h + stretch)))
    return canvas


## A soft oval under the feet (the box figures' shadow was a hard dark diamond the size of a tile).
## The other stride from one: the legs below LEG_CUT of the figure are mirrored about the hip centre, so the lifted
## foot behind becomes the foot stepping in front (img2img prompts could not pick the leg reliably). The rows just
## below the cut keep the original pixels where the mirror leaves them empty, so hands and bags are not cut off.
LEG_CUT = 0.68


def other_leg(fig: Image.Image) -> Image.Image:
    a = np.asarray(fig).copy()
    h, w = a.shape[:2]
    y0 = int(h * LEG_CUT)
    # The legs' columns: what the lowest 30% of the figure covers (feet and shins), a little wider. Only those columns
    # are mirrored, about their own centre, so a bag or a hand beside the legs keeps its pixels.
    low = np.where(a[int(h * 0.70):][..., 3].max(axis=0) > 40)[0]
    if len(low) == 0:
        return fig.copy()
    x0, x1 = max(int(low.min()) - 4, 0), min(int(low.max()) + 4, w - 1)
    cx2 = x0 + x1   # twice the centre: the mirror of x is cx2 - x, which stays inside [x0, x1]
    legs = a[y0:].copy()
    out = legs.copy()
    for x in range(x0, x1 + 1):
        out[:, x] = legs[:, cx2 - x]
    band = min(14, legs.shape[0])   # just under the cut, keep the original where the mirror leaves a gap
    keep = (out[:band, x0:x1 + 1, 3] < 40) & (legs[:band, x0:x1 + 1, 3] > 40)
    out[:band, x0:x1 + 1][keep] = legs[:band, x0:x1 + 1][keep]
    a[y0:] = out
    return Image.fromarray(a, "RGBA")


def _alpha_of(rgb: Image.Image) -> Image.Image:
    im = np.asarray(rgb.convert("RGB")).astype(np.int32)
    mn, mx = im.min(axis=2), im.max(axis=2)
    bg = (mn >= 235) & ((mx - mn) <= 14)
    lab, _ = ndimage.label(bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    mask = np.isin(lab, list(border))
    return Image.fromarray(np.where(mask, 0, 255).astype(np.uint8))


## other_leg on a whole render (white background, full canvas): for the img2img seam clean-up (comfy_chibi.py --clean).
def other_leg_raw(raw: Image.Image) -> Image.Image:
    rgba = raw.convert("RGB").convert("RGBA")
    rgba.putalpha(_alpha_of(raw))
    box = rgba.getbbox()
    fig = rgba.crop(box)
    out = Image.new("RGBA", rgba.size, (255, 255, 255, 0))
    out.alpha_composite(other_leg(fig), (box[0], box[1]))
    return out


def soft_shadow() -> Image.Image:
    w, h = 96, 34
    y, x = np.mgrid[0:CANVAS[1], 0:CANVAS[0]]
    d = ((x - FEET[0]) / (w / 2)) ** 2 + ((y - (FEET[1] + 2)) / (h / 2)) ** 2
    a = np.clip(1.0 - d, 0, 1) ** 1.5 * 110
    img = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
    img[..., 3] = a.astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def build(person: str, seed: int) -> None:
    if not (SRC / ("%s_front_%d.png" % (person, seed))).exists():
        print("skip", person, "(no render yet)")
        return
    front = cut(SRC / ("%s_front_%d.png" % (person, seed)))
    back = cut(SRC / ("%s_back_%d.png" % (person, seed)))
    views = {0: ImageOps.mirror(front), 1: front, 2: back, 3: ImageOps.mirror(back)}
    # Walk cycle: standing, stride A, standing, stride B (img2img stride poses, tools/assets/comfy_chibi.py --steps);
    # without the stride renders it falls back to the stretched standing pose.
    steps = {}
    for view, flip_dirs in (("front", (1, 0)), ("back", (2, 3))):
        a = SRC / ("%s_%s_stepA_%d.png" % (person, view, seed))
        b = SRC / ("%s_%s_stepB_%d.png" % (person, view, seed))
        if a.exists():
            ia = cut(a)
            cleaned = SRC / ("%s_%s_stepB2_%d.png" % (person, view, seed))   # the mirror with its seam redrawn (img2img)
            ib = cut(cleaned) if cleaned.exists() else other_leg(ia)   # the other leg forward (stepB raised the same foot)
            steps[flip_dirs[0]] = (ia, ib)
            steps[flip_dirs[1]] = (ImageOps.mirror(ia), ImageOps.mirror(ib))
    k_front, k_back = scale_of(front), scale_of(back)
    eat_path = SRC / ("%s_eat_%d.png" % (person, seed))   # #134: seated with an onigiri, for every facing
    eats = not person.startswith("staff_") and person != "clerk"   # staff never sit down to eat (#134)
    eat = cut(eat_path) if eats and eat_path.exists() else None
    vid = "chibi_" + person
    out = DST / vid
    out.mkdir(parents=True, exist_ok=True)
    base = json.loads((DST / "customer_a" / "customer_a.character.json").read_text(encoding="utf-8"))
    base["visual_id"] = vid
    base["directions"] = {}
    for d, fig in views.items():
        base["directions"][str(d)] = {}
        k = k_front if d in (0, 1) else k_back
        for anim, bobs in BOBS.items():
            names = []
            for i, dy in enumerate(bobs):
                name = "d%d_%s_f%d.png" % (d, anim, i)
                pose = fig
                if anim == "walk" and d in steps:
                    pose = [fig, steps[d][0], steps[d][0], fig, steps[d][1], steps[d][1]][i]
                    dy = [0, 2, 3, 0, 2, 3][i]
                place(pose, dy, k).save(out / name)
                names.append(name)
            base["directions"][str(d)][anim] = names
        if eat is not None:
            pose = eat if d in (1, 2) else ImageOps.mirror(eat)   # facing left for S / W, right for E / N
            names = []
            for i, dy in enumerate([0, 2]):
                name = "d%d_eat_f%d.png" % (d, i)
                place(pose, dy, k_front).save(out / name)
                names.append(name)
            base["directions"][str(d)]["eat"] = names
    if eat is not None:
        base["animations"]["eat"] = {"frames": 2, "fps": 1.5, "loop": True}
    soft_shadow().save(out / "shadow.png")
    (out / (vid + ".character.json")).write_text(json.dumps(base, ensure_ascii=False, indent=2), encoding="utf-8")
    print(vid)


if __name__ == "__main__":
    for p, s in PICKS.items():
        build(p, s)
