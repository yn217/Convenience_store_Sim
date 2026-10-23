"""Generate a review-only bottle_500 candidate using the repo's iso2x contract.

This is a deterministic asset-stage reproduction script. It keeps the existing
bottle_500 real-world dimensions and emits four quarter-turn RGBA PNGs plus a
manifest. It intentionally does not touch Godot scenes, runtime data, or the
existing generated product assets.
"""
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
SIZE = 256
DIMENSIONS_M = {"width": 0.068, "depth": 0.068, "height": 0.225}
PROJECTION_ID = "iso2x_v1"


def render(rotation: int) -> Image.Image:
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    cx, bottom = 128, 188
    width, height = 38, 118
    left, right, top = cx - width // 2, cx + width // 2, bottom - height
    base = (151, 205, 224, 255)
    edge = (34, 96, 148, 255)
    dark = (25, 70, 110, 255)
    accent = (34, 96, 148, 235)
    d.ellipse((left - 7, bottom - 4, right + 7, bottom + 8), fill=(20, 24, 28, 72))
    d.rounded_rectangle((left, top + 14, right, bottom), radius=9, fill=base, outline=edge, width=3)
    neck = 13
    d.rounded_rectangle((cx - neck // 2, top, cx + neck // 2, top + 22), radius=3, fill=dark)
    d.rectangle((left + 3, top + 61, right - 3, top + 82), fill=accent)
    d.rectangle((left + 7, top + 67, right - 7, top + 76), fill=(245, 250, 252, 235))
    d.text((cx - 14, top + 67), "AQUA", fill=(34, 96, 148, 235))
    if rotation in (1, 2):
        d.line((right - 5, top + 20, right - 5, bottom - 10), fill=(255, 255, 255, 95), width=3)
    else:
        d.line((left + 5, top + 20, left + 5, bottom - 10), fill=(255, 255, 255, 95), width=3)
    return im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    directions = {}
    for rotation in range(4):
        name = f"bottle_500_iso2x_review_{rotation}.png"
        render(rotation).save(OUT / name, "PNG", optimize=True)
        directions[str(rotation)] = {"file": name, "anchor_px": [128, 188], "rotation_quarter_turns": rotation}
    manifest = {
        "manifest_version": 1,
        "status": "review-only",
        "runtime_approved": False,
        "source_baseline": "assets/generated/products/bottle_500/bottle_500_0.png",
        "shape_id": "bottle_500",
        "dimensions_m": DIMENSIONS_M,
        "projection_id": PROJECTION_ID,
        "camera": {"azimuth_deg": 45.0, "elevation_deg": 30.0, "scale": "iso2x"},
        "ground_contact": {"anchor": "world_origin", "anchor_px": [128, 188]},
        "directions": directions,
        "generator": "generate_bottle_500_iso2x_review.py",
    }
    (OUT / "bottle_500_iso2x_review.manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    provenance = {
        "status": "review-only",
        "runtime_approved": False,
        "pipeline": "existing iso2x_v1 asset-stage contract; Blender-compatible dimensions and camera metadata",
        "source_baseline": "assets/generated/products/bottle_500/bottle_500_0.png",
        "generator": "assets/source/textures/packages/candidates/bottle_500_iso2x_review/generate_bottle_500_iso2x_review.py",
        "generator_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "directions": [directions[str(i)]["file"] for i in range(4)],
        "notes": "Fictional generic label; no runtime wiring; candidate for visual review only.",
    }
    (OUT / "bottle_500_iso2x_review.provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
