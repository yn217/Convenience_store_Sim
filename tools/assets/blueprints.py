"""Fixture blueprints (docs/implementation/06_ASSET_BLUEPRINTS_AND_VALIDATION.md §1, §2, §4).

A blueprint is built from axis-aligned boxes in rotation-0 game coordinates. Rotating a box by a
quarter turn keeps it axis-aligned, so rotation is exact (never an image rotation). Only the
types needed by the pipeline issue (#8) are modelled here: 1x1 warmer_oden, 1x2 shelf_general,
2x2 freezer_ice. The remaining types are added with #9 / #22.
"""
from dataclasses import dataclass

import iso2x

# Standard part thicknesses (06 §1).
FRAME = 0.025
BOARD = 0.018
GLASS = 0.010
BASE = 0.08
POST = 0.04

LAYERS = ("body", "shadow", "glass_front")
MATERIALS = (
    "frame_metal", "shelf_white", "clear_glass", "cool_white_led",
    "dark_polymer", "label_rail", "product_surface",
)
BODY_INSET = 0.04          # body stays 0.04 m inside the footprint on every side
SHADOW_GROW = 0.12         # shadow may extend <= 0.15 m past the footprint (02 §B)


@dataclass(frozen=True)
class Box:
    x0: float
    y0: float
    z0: float
    x1: float
    y1: float
    z1: float
    material: str
    layer: str = "body"

    def rotated(self, w, h, rotation):
        ax, ay = iso2x.transform_point(self.x0, self.y0, w, h, rotation)
        bx, by = iso2x.transform_point(self.x1, self.y1, w, h, rotation)
        return Box(min(ax, bx), min(ay, by), self.z0, max(ax, bx), max(ay, by), self.z1, self.material, self.layer)

    def corners(self):
        return [(x, y, z) for x in (self.x0, self.x1) for y in (self.y0, self.y1) for z in (self.z0, self.z1)]


def _body_rect(w, h):
    x0, y0, x1, y1 = iso2x.footprint_rect(w, h)
    return (x0 + BODY_INSET, y0 + BODY_INSET, x1 - BODY_INSET, y1 - BODY_INSET)


def _rack(d, rows, trim=None, back=True):
    """Open rack: base, four posts, optional back panel, top cap, one board per row, optional trim rail."""
    x0, y0, x1, y1 = _body_rect(*_wh(d))
    height = d["dimensions_m"]["height"]
    boxes = [Box(x0, y0, 0.0, x1, y1, BASE, "dark_polymer")]
    for px in (x0, x1 - POST):
        for py in (y0, y1 - POST):
            boxes.append(Box(px, py, BASE, px + POST, py + POST, height - 0.02, "frame_metal"))
    if back:
        boxes.append(Box(x0, y0, BASE, x0 + 0.02, y1, height - 0.02, "shelf_white"))   # back panel (W side)
    boxes.append(Box(x0, y0, height - 0.02, x1, y1, height, "shelf_white"))            # top cap
    for z in rows:
        boxes.append(Box(x0 + 0.02, y0, z - BOARD, x1, y1, z, "shelf_white"))
        if trim:
            boxes.append(Box(x1 - 0.02, y0 + POST, z - BOARD - 0.04, x1, y1 - POST, z - BOARD, trim))   # price-label rail
    return boxes, []


def _shelf_general(d):
    return _rack(d, ROW_HEIGHTS["shelf_general"])


def _shelf_onigiri(d):
    return _rack(d, ROW_HEIGHTS["shelf_onigiri"], trim="label_rail")


def _shelf_noodle(d):
    return _rack(d, ROW_HEIGHTS["shelf_noodle"], trim="label_rail")


def _shelf_bread(d):
    return _rack(d, ROW_HEIGHTS["shelf_bread"], back=False)       # open-backed bread rack


def _shelf_snack(d):
    return _rack(d, ROW_HEIGHTS["shelf_snack"], trim="label_rail")


def _warmer_oden(d):
    x0, y0, x1, y1 = _body_rect(*_wh(d))
    height = d["dimensions_m"]["height"]
    pot_top = 0.95
    boxes = [
        Box(x0, y0, 0.0, x1, y1, 0.85, "dark_polymer"),
        Box(x0, y0, 0.85, x1, y1, pot_top, "frame_metal"),
    ]
    glass = [Box(x0, y0, pot_top, x1, y1, pot_top + GLASS, "clear_glass", "glass_front")]
    boxes.append(Box(x0, y1 - FRAME, pot_top + GLASS, x1, y1, height, "frame_metal"))     # hood back rail (S side, opposite the N front)
    return boxes, glass


def _freezer_ice(d):
    x0, y0, x1, y1 = _body_rect(*_wh(d))
    height = d["dimensions_m"]["height"]
    rim = 0.08
    boxes = [Box(x0, y0, 0.0, x1, y1, 0.8, "shelf_white")]
    boxes += [
        Box(x0, y0, 0.8, x1, y0 + rim, height, "frame_metal"),
        Box(x0, y1 - rim, 0.8, x1, y1, height, "frame_metal"),
        Box(x0, y0 + rim, 0.8, x0 + rim, y1 - rim, height, "frame_metal"),
        Box(x1 - rim, y0 + rim, 0.8, x1, y1 - rim, height, "frame_metal"),
    ]
    boxes.append(Box(x0 + rim, y0 + rim, 0.8, x1 - rim, y1 - rim, 0.84, "cool_white_led"))  # tub floor light
    glass = [Box(x0 + rim, y0 + rim, height - 0.03, x1 - rim, y1 - rim, height - 0.03 + GLASS, "clear_glass", "glass_front")]
    return boxes, glass


def _register_basic(d):
    x0, y0, x1, y1 = _body_rect(*_wh(d))
    boxes = [
        Box(x0, y0, 0.0, x1, y1, BASE, "dark_polymer"),
        Box(x0, y0, BASE, x1, y1, 0.90, "shelf_white"),                       # counter body
        Box(x0 - 0.0, y0, 0.90, x1, y1, 0.92, "frame_metal"),                  # service top (0.92 m)
        Box(x1 - 0.02, y0 + 0.10, 0.55, x1, y1 - 0.10, 0.62, "label_rail"),    # customer-side trim
        Box(x0 + 0.05, 0.25, 0.92, x0 + 0.40, 0.85, 1.10, "dark_polymer"),     # POS terminal
        Box(x0 + 0.05, 0.28, 1.10, x0 + 0.12, 0.82, 1.20, "dark_polymer"),     # display on a stalk
    ]
    return boxes, []


def _fridge(d, rows):
    """Glass-door chilled case; the body top sits 0.10 m under the stated height."""
    x0, y0, x1, y1 = _body_rect(*_wh(d))
    height = d["dimensions_m"]["height"]
    door_x0 = x1 - 0.03
    top = height - 0.10
    mid = (y0 + y1) / 2
    boxes = [
        Box(x0, y0, 0.0, x1, y1, BASE, "dark_polymer"),
        Box(x0, y0, BASE, x0 + 0.06, y1, top, "shelf_white"),                 # back panel (W)
        Box(x0, y0, BASE, door_x0, y0 + POST, top, "shelf_white"),            # side panels
        Box(x0, y1 - POST, BASE, door_x0, y1, top, "shelf_white"),
        Box(x0, y0, top, x1, y1, height, "shelf_white"),                      # top cap
        Box(x1 - 0.05, y0 + 0.06, top - 0.06, x1 - 0.01, y1 - 0.06, top - 0.02, "cool_white_led"),
        # door frame: stiles, centre mullion, top and bottom rails
        Box(door_x0, y0, BASE, x1, y0 + POST, top, "frame_metal"),
        Box(door_x0, y1 - POST, BASE, x1, y1, top, "frame_metal"),
        Box(door_x0, mid - 0.02, BASE, x1, mid + 0.02, top, "frame_metal"),
        Box(door_x0, y0, top - 0.08, x1, y1, top, "frame_metal"),
        Box(door_x0, y0, BASE, x1, y1, 0.10, "frame_metal"),
    ]
    for z in rows:
        boxes.append(Box(x0 + 0.06, y0 + POST, z - BOARD, door_x0, y1 - POST, z, "shelf_white"))
    glass = [
        Box(x1 - GLASS, y0 + POST, 0.10, x1, mid - 0.02, top - 0.08, "clear_glass", "glass_front"),
        Box(x1 - GLASS, mid + 0.02, 0.10, x1, y1 - POST, top - 0.08, "clear_glass", "glass_front"),
    ]
    return boxes, glass


def _fridge_drink(d):
    return _fridge(d, ROW_HEIGHTS["fridge_drink"])


def _fridge_dessert(d):
    return _fridge(d, ROW_HEIGHTS["fridge_dessert"])


BUILDERS = {
    "register_basic": _register_basic,
    "fridge_drink": _fridge_drink,
    "shelf_general": _shelf_general,
    "warmer_oden": _warmer_oden,
    "freezer_ice": _freezer_ice,
    "shelf_onigiri": _shelf_onigiri,
    "shelf_noodle": _shelf_noodle,
    "shelf_bread": _shelf_bread,
    "shelf_snack": _shelf_snack,
    "fridge_dessert": _fridge_dessert,
}
# Row heights (m) of the display slots, bottom to top (06 §2).
ROW_HEIGHTS = {
    "shelf_general": [0.32, 0.64, 0.96, 1.28], "fridge_drink": [0.46, 0.96, 1.46],
    "shelf_onigiri": [0.40, 0.80, 1.20], "shelf_noodle": [0.32, 0.70, 1.08, 1.46],
    "shelf_bread": [0.45, 0.85, 1.25], "shelf_snack": [0.32, 0.68, 1.04, 1.40],
    "fridge_dessert": [0.40, 0.85, 1.30],
}


def _wh(d):
    return d["footprint"]["w"], d["footprint"]["h"]


def supported_types():
    return sorted(BUILDERS)


def build(d):
    """-> {boxes, shadow (x0,y0,x1,y1), slots {slot_id: [(item_id, (x,y,z))]}} in rotation-0 coords."""
    boxes, glass = BUILDERS[d["type_id"]](d)
    w, h = _wh(d)
    x0, y0, x1, y1 = _body_rect(w, h)
    shadow = (x0 - SHADOW_GROW, y0 - SHADOW_GROW, x1 + SHADOW_GROW, y1 + SHADOW_GROW)
    return {"boxes": boxes + glass, "shadow": shadow, "slots": _slots(d, (x0, y0, x1, y1))}


def _slots(d, body):
    """Display-slot anchors in 3D (never a rotated 2D image). 'rack': 8 containers per row along the
    long side at x = 0.30 (06 §4). 'grid': one anchor per cell, laid out evenly over the top."""
    t = d["type_id"]
    x0, y0, x1, y1 = body
    slots = {}
    if t in ROW_HEIGHTS:
        for row, slot in enumerate(d["shelf_slots"]):
            z = ROW_HEIGHTS[t][row] + 0.001
            slots[slot["slot_id"]] = [
                ("%s_item%d" % (slot["slot_id"], i), (0.30, -0.35 + i * (1.70 / 7.0), z)) for i in range(8)
            ]
        return slots
    if not d["shelf_slots"]:
        return slots
    cells = [s["slot_id"] for s in d["shelf_slots"]]
    cols = 3 if t == "warmer_oden" else 2
    rows = (len(cells) + cols - 1) // cols
    z = 0.95 if t == "warmer_oden" else 0.82
    for i, cell in enumerate(cells):
        c, r = i % cols, i // cols
        px = x0 + (x1 - x0) * (c + 0.5) / cols
        py = y0 + (y1 - y0) * (r + 0.5) / rows
        slots[cell] = [("%s_item0" % cell, (px, py, z))]
    return slots


def rotated(bp, d, rotation):
    w, h = _wh(d)
    boxes = [b.rotated(w, h, rotation) for b in bp["boxes"]]
    sx0, sy0, sx1, sy1 = bp["shadow"]
    ax, ay = iso2x.transform_point(sx0, sy0, w, h, rotation)
    bx, by = iso2x.transform_point(sx1, sy1, w, h, rotation)
    slots = {}
    for sid, items in bp["slots"].items():
        slots[sid] = [(iid, iso2x.transform_point(p[0], p[1], w, h, rotation) + (p[2],)) for iid, p in items]
    return {"boxes": boxes, "shadow": (min(ax, bx), min(ay, by), max(ax, bx), max(ay, by)), "slots": slots}


def front_edges(d, rotation):
    return sorted(iso2x.rotate_edge(e, rotation) for e in d["access_edges"])


def mesh_bbox(boxes, layers=("body", "glass_front")):
    pts = [c for b in boxes if b.layer in layers for c in b.corners()]
    lo = tuple(min(p[i] for p in pts) for i in range(3))
    hi = tuple(max(p[i] for p in pts) for i in range(3))
    return lo, hi


def problems(d):
    """Blueprint-level contract checks (06 §6): sizes and clearances, independent of Blender."""
    out = []
    w, h = _wh(d)
    for r in range(4):
        bp = rotated(build(d), d, r)
        rx0, ry0, rx1, ry1 = iso2x.rotated_footprint_rect(w, h, r)
        lo, hi = mesh_bbox(bp["boxes"])
        eps = 1e-9
        if lo[0] < rx0 + BODY_INSET - eps or lo[1] < ry0 + BODY_INSET - eps or hi[0] > rx1 - BODY_INSET + eps or hi[1] > ry1 - BODY_INSET + eps:
            out.append("%s r%d: mesh leaves the body box [footprint-0.04 m]" % (d["type_id"], r))
        rw, rh = (w, h) if r % 2 == 0 else (h, w)
        if (hi[0] - lo[0]) > rw - 0.08 + eps or (hi[1] - lo[1]) > rh - 0.08 + eps:
            out.append("%s r%d: mesh larger than footprint-0.08 m" % (d["type_id"], r))
        if abs((hi[2] - lo[2]) - d["dimensions_m"]["height"]) > 0.01:
            out.append("%s r%d: height %.3f != %.3f +/- 0.01" % (d["type_id"], r, hi[2] - lo[2], d["dimensions_m"]["height"]))
        sx0, sy0, sx1, sy1 = bp["shadow"]
        if sx0 < rx0 - 0.15 or sy0 < ry0 - 0.15 or sx1 > rx1 + 0.15 or sy1 > ry1 + 0.15:
            out.append("%s r%d: shadow extends more than 0.15 m past the footprint" % (d["type_id"], r))
        for sid, items in bp["slots"].items():
            for iid, p in items:
                if not (lo[0] <= p[0] <= hi[0] and lo[1] <= p[1] <= hi[1]):
                    out.append("%s r%d: slot %s outside the body" % (d["type_id"], r, iid))
    if sorted(d["access_edges"]) != sorted(d["access_edges"]):
        out.append("access edges not sortable")
    return out
