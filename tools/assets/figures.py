"""Customer figure blueprints (docs/implementation/14_ANIMATION_AUDIO_VFX_CONTRACT.md §2).

A customer is a stack of axis-aligned boxes in the figure frame (+x forward, +y to the figure's
right, z up, feet on z = 0, pivot = the cell origin). A quarter-turn facing keeps every box axis
aligned, so the four directions are rendered from a rotated 3D model - never a mirrored or turned
image. Poses: walk 6 frames, idle 2, inspect (reaching to a shelf) 4. Boxes, no textures: three
variants differ in height, hair, clothing colours and a shoulder bag.
Pure Python (shared by the Blender renderer, the sprite builder and the validator).
"""
import math

import iso2x

FACINGS = ("E", "S", "W", "N")          # facing f = f clockwise quarter turns from +x
ANIMS = {"walk": 6, "idle": 2, "inspect": 4}
# Playback rate in frames per game second (14 §2: walk cycle 0.75 s, idle 1.2 s, pickup 0.45 s).
FPS = {"walk": 8.0, "idle": 2.0 / 1.2, "inspect": 4.0 / 0.45}
LOOP = {"walk": True, "idle": True, "inspect": False}

VARIANTS = {
    "customer_a": {"height": 1.65, "shirt": (0.22, 0.42, 0.72), "pants": (0.16, 0.18, 0.24), "hair": (0.10, 0.07, 0.05), "skin": (0.86, 0.68, 0.55), "bag": None},
    "customer_b": {"height": 1.58, "shirt": (0.78, 0.30, 0.25), "pants": (0.30, 0.28, 0.22), "hair": (0.45, 0.30, 0.12), "skin": (0.92, 0.76, 0.64), "bag": (0.25, 0.45, 0.30)},
    "customer_c": {"height": 1.72, "shirt": (0.88, 0.80, 0.30), "pants": (0.12, 0.14, 0.18), "hair": (0.55, 0.55, 0.58), "skin": (0.70, 0.52, 0.40), "bag": None},
}
SHOE = (0.06, 0.06, 0.07)
SHADOW_HALF = 0.30


def material_id(variant, part):
    return "c_%s_%s" % (variant, part)


def pose_boxes(variant, anim, frame):
    """-> list of (x0, y0, z0, x1, y1, z1, material_id) in the figure frame."""
    v = VARIANTS[variant]
    h = v["height"]
    mid = lambda part: material_id(variant, part)  # noqa: E731
    leg_top = 0.485 * h
    head_h = 0.15 * h
    shoulder = h - head_h - 0.03
    swing = math.sin(2.0 * math.pi * frame / ANIMS["walk"]) if anim == "walk" else 0.0
    breathe = 0.008 * frame if anim == "idle" else 0.0
    boxes = []
    for side, y in ((-1, -0.09), (1, 0.09)):                     # legs (walk swings them opposite)
        dx = 0.13 * swing * side
        boxes.append((dx - 0.08, y - 0.07, 0.06, dx + 0.08, y + 0.07, leg_top, mid("pants")))
        boxes.append((dx - 0.08, y - 0.07, 0.0, dx + 0.14, y + 0.07, 0.06, "shoe"))
    boxes.append((-0.10, -0.19, leg_top, 0.10, 0.19, h - head_h + breathe, mid("shirt")))   # torso
    boxes.append((-0.10, -0.10, h - head_h + breathe, 0.10, 0.10, h - 0.05 + breathe, mid("skin")))   # head
    boxes.append((-0.105, -0.105, h - 0.05 + breathe, 0.105, 0.105, h + breathe, mid("hair")))        # hair cap
    arm_len = 0.58
    for side, y in ((-1, -0.235), (1, 0.235)):
        if anim == "inspect" and side == 1:
            reach = (0.10, 0.22, 0.34, 0.22)[frame]
            z0 = h * (0.60, 0.66, 0.72, 0.66)[frame]
            boxes.append((-0.05, y - 0.045, z0, 0.05, y + 0.045, shoulder, mid("shirt")))        # upper arm
            boxes.append((0.05, y - 0.045, z0, 0.05 + reach, y + 0.045, z0 + 0.09, mid("skin")))  # forearm reaching out
            continue
        dx = -0.10 * swing * side if anim == "walk" else 0.0
        boxes.append((dx - 0.05, y - 0.045, shoulder - arm_len + breathe, dx + 0.05, y + 0.045, shoulder + breathe, mid("shirt")))
    if v["bag"] is not None:
        boxes.append((-0.07, -0.34, 0.50 * h, 0.07, -0.26, 0.50 * h + 0.24, mid("bag")))
    return boxes


def facing_boxes(variant, anim, frame, facing):
    out = []
    for x0, y0, z0, x1, y1, z1, m in pose_boxes(variant, anim, frame):
        ax, ay = iso2x.rotate_point(x0, y0, facing)
        bx, by = iso2x.rotate_point(x1, y1, facing)
        out.append((min(ax, bx), min(ay, by), z0, max(ax, bx), max(ay, by), z1, m))
    return out


def shadow_box():
    return (-SHADOW_HALF, -SHADOW_HALF, 0.0, SHADOW_HALF, SHADOW_HALF, 0.002, "shadow")


def frame_name(facing, anim, frame):
    return "%d/%s/f%d" % (facing, anim, frame)
