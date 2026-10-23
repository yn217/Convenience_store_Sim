"""Preview product overlays using fixture manifest slot anchors.

This is an asset-only integration gate. It mirrors ShelfDisplay's 0/2/5/8 fill steps and
does not modify Godot scenes or runtime logic.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "assets" / "generated" / "fixtures"
PRODUCTS = ROOT / "assets" / "generated" / "products"
OUT = ROOT / "build" / "asset_audit" / "product_lod"
STATES = {"empty": 0, "low": 2, "medium": 5, "full": 8}


def _overlay(base, product, anchors, count):
    out = base.copy()
    # Product templates are source-resolution canvases; crop their transparent bounds and
    # scale to a compact slot-sized sprite before anchoring at the manifest pixel position.
    bbox = product.getbbox()
    # The source product canvas is 256 px/tile; the visible container must remain
    # inside the 1.70 m display run when eight items share a row.
    sprite = product.crop(bbox).resize((max(8, int((bbox[2] - bbox[0]) * 0.28)), max(8, int((bbox[3] - bbox[1]) * 0.28))), Image.Resampling.LANCZOS)
    for i, anchor in enumerate(anchors[:count]):
        x = int(anchor[0] - sprite.width / 2)
        y = int(anchor[1] - sprite.height)
        out.alpha_composite(sprite, (x, y))
    return out


def main():
    manifest = json.loads((FIXTURES / "shelf_general" / "shelf_general_a.visual.json").read_text(encoding="utf-8"))
    product = Image.open(PRODUCTS / "snack_pouch" / "snack_pouch_0.png").convert("RGBA")
    rows = []
    for rotation in range(4):
        rot = manifest["rotations"][str(rotation)]
        body = Image.open(FIXTURES / "shelf_general" / rot["layers"]["body"]).convert("RGBA")
        anchors = [p for key, p in rot["slot_anchors_px"].items() if key.startswith("row0_")]
        for state, count in STATES.items():
            preview = _overlay(body, product, anchors, count)
            label = Image.new("RGBA", (preview.width, 28), (45, 52, 58, 230))
            ImageDraw.Draw(label).text((8, 7), f"r{rotation} row0 {state} ({count}/8)", fill=(255, 255, 255, 255))
            card = Image.new("RGBA", (preview.width, preview.height + label.height), (0, 0, 0, 0))
            card.alpha_composite(preview, (0, label.height))
            card.alpha_composite(label, (0, 0))
            rows.append(card)
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (max(x.width for x in rows), sum(x.height for x in rows)), (130, 138, 135, 255))
    y = 0
    for card in rows:
        sheet.alpha_composite(card, (0, y))
        y += card.height
    sheet.save(OUT / "shelf_general_row0_lod.png", "PNG")
    print(f"wrote {OUT / 'shelf_general_row0_lod.png'}")


if __name__ == "__main__":
    main()
