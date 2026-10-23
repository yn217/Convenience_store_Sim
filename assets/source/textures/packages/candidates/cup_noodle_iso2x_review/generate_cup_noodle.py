from __future__ import annotations

import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
CANVAS = (64, 64)
DIMENSIONS_M = [0.110, 0.110, 0.120]
ANCHOR = [32, 50]

def draw_view(direction: int) -> Image.Image:
    im = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Deterministic stylized cup-noodle package, source scale 2x.
    cx, bottom = 32, 50
    top_y, rim_y = 29, 33
    body = [(20, rim_y), (44, rim_y), (40, bottom), (24, bottom)]
    d.polygon(body, fill=(235, 235, 226, 255), outline=(75, 75, 70, 255))
    d.ellipse((20, top_y, 44, rim_y + 5), fill=(245, 245, 235, 255), outline=(65, 65, 60, 255))
    d.ellipse((23, top_y + 2, 41, rim_y + 2), fill=(187, 112, 46, 255), outline=(105, 60, 28, 255))
    d.arc((25, top_y + 3, 39, rim_y + 1), 15, 165, fill=(246, 205, 95, 255), width=2)
    d.rectangle((24, 37, 40, 44), fill=(205, 42, 38, 255))
    d.line((24, 37, 40, 37), fill=(255, 224, 123, 255), width=1)
    d.text((27, 38), "NOODLE", fill=(255, 245, 190, 255))
    # Direction-specific deterministic accent; geometry remains physically identical.
    accents = [(255, 188, 54, 255), (48, 112, 180, 255), (54, 145, 74, 255), (143, 65, 155, 255)]
    d.line((26, 46, 38, 46), fill=accents[direction], width=2)
    # shared 8px alpha padding is represented by the 64px crop around the alpha bbox.
    return im

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    files = []
    for direction in range(4):
        name = f"cup_noodle_r{direction}.png"
        path = ROOT / name
        draw_view(direction).save(path, format="PNG", optimize=False, compress_level=9)
        files.append({"direction": direction, "path": name, "sha256": sha256(path), "mime": "image/png"})
    manifest = {
        "schema_version": "visual-manifest-v1",
        "asset_kind": "product_candidate",
        "shape_id": "cup_noodle",
        "dimensions_m": DIMENSIONS_M,
        "projection_id": "iso2x_v1",
        "source_px_per_tile": [256, 128],
        "world_units_per_tile": 1.0,
        "slot_units": 1,
        "anchor_px": ANCHOR,
        "canvas_px": list(CANVAS),
        "origin_pivot": "world_origin_floor",
        "directions": files,
        "layers": ["product_surface"],
        "slots": [],
        "runtime_approved": False,
        "provenance": {
            "generator": "generate_cup_noodle.py",
            "method": "deterministic_pillow",
            "source_contracts": [
                "docs/implementation/06_ASSET_BLUEPRINTS_AND_VALIDATION.md",
                "docs/implementation/02_GRID_AND_ASSET_CONTRACT.md",
            ],
            "blender_available": False,
            "generated_utc": "2026-10-24T00:00:00Z",
        },
    }
    (ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    hashes = {p.name: sha256(p) for p in sorted(ROOT.iterdir()) if p.is_file() and p.name != "SHA256SUMS.txt"}
    (ROOT / "SHA256SUMS.txt").write_text("".join(f"{digest}  {name}\n" for name, digest in hashes.items()), encoding="ascii")

if __name__ == "__main__":
    main()
