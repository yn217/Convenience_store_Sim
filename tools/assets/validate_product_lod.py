"""Validate stock-state overlay counts without involving Godot or fixture depth.

This is intentionally narrower than Issue #26: it proves that empty/low/medium/full
produce 0/2/5/8 visible product overlays at every fixture rotation.  Occlusion and
runtime draw order remain separate acceptance gates.
"""
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "assets/generated/fixtures/shelf_general/shelf_general_a.visual.json"
PRODUCT = ROOT / "assets/generated/products/snack_pouch/snack_pouch_0.png"
STATES = {"empty": 0, "low": 2, "medium": 5, "full": 8}


def overlay_alpha(canvas, product, anchors, count):
    bbox = product.getbbox()
    sprite = product.crop(bbox).resize((
        max(8, int((bbox[2] - bbox[0]) * 0.28)),
        max(8, int((bbox[3] - bbox[1]) * 0.28)),
    ), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    for anchor in anchors[:count]:
        out.alpha_composite(sprite, (int(anchor[0] - sprite.width / 2), int(anchor[1] - sprite.height)))
    return sum(1 for pixel in out.getdata() if pixel[3] > 0)


def main():
    manifest = json.loads(FIXTURE.read_text(encoding="utf-8"))
    product = Image.open(PRODUCT).convert("RGBA")
    problems = []
    for rotation in range(4):
        rot = manifest["rotations"][str(rotation)]
        anchors = [point for key, point in rot["slot_anchors_px"].items() if key.startswith("row0_")]
        if len(anchors) != 8:
            problems.append("r%d: expected 8 row0 anchors, found %d" % (rotation, len(anchors)))
            continue
        counts = [overlay_alpha(tuple(rot["canvas_px"]), product, anchors, amount) for amount in STATES.values()]
        if any(a >= b for a, b in zip(counts, counts[1:])):
            problems.append("r%d: visible alpha counts are not increasing: %s" % (rotation, counts))
        print("r%d: empty/low/medium/full=%s" % (rotation, counts))
    print("product LOD check: %d rotations, %d problem(s)" % (4, len(problems)))
    for problem in problems:
        print("- " + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
