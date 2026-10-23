"""Create a compact visual-review sheet for customer sprite manifests.

This is a review aid, not a replacement for the runtime occlusion test.  It
shows representative walk/idle/inspect frames for all variants and facings on
the manifest canvas, preserving the shared anchor used by the validator.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIR = ROOT / "assets" / "generated" / "characters"
DEFAULT_OUT = ROOT / "build" / "asset_audit" / "customers_contact.png"
ANIMS = ("walk", "idle", "inspect", "checkout")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", type=Path, default=DEFAULT_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    manifests = sorted(args.dir.glob("*/*.character.json"))
    if not manifests:
        raise SystemExit("no customer manifests found")
    all_manifests = [json.loads(path.read_text(encoding="utf-8")) for path in manifests]
    cw = max(m["canvas_px"][0] for m in all_manifests)
    ch = max(m["canvas_px"][1] for m in all_manifests)
    target_anchor = (cw // 2, ch - 20)
    margin, label_h = 10, 22
    cell_w, cell_h = cw + margin * 2, ch + label_h + margin * 2
    rows = sum(len(m.get("animations", {})) for m in all_manifests)
    sheet = Image.new("RGBA", (4 * cell_w, rows * cell_h), (100, 108, 105, 255))
    draw = ImageDraw.Draw(sheet)
    row = 0
    for mpath, manifest in zip(manifests, all_manifests):
        for anim in manifest.get("animations", {}):
            for direction in range(4):
                rel = manifest["directions"][str(direction)][anim][0]
                image = Image.open(mpath.parent / rel).convert("RGBA")
                x = int(direction * cell_w + margin + target_anchor[0] - manifest["anchor_px"][0])
                y = int(row * cell_h + label_h + margin + target_anchor[1] - manifest["anchor_px"][1])
                sheet.alpha_composite(image, (x, y))
                draw.text((x, row * cell_h + margin), "%s %s d%d" % (
                    manifest["visual_id"], anim, direction), fill=(255, 255, 255, 255))
            row += 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out, "PNG", optimize=True)
    print("wrote %s (%d manifests, %d representative frames)" % (
        args.out, len(manifests), len(manifests) * len(ANIMS) * 4))


if __name__ == "__main__":
    main()
