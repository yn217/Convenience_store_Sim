from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
SIZE = (512, 640)
PIVOT = (256.0, 420.0)
PROJECTION = "iso2x_v1"
Z_SCALE = 156.76734354
SEED = "shelf_onigiri_candidate_v1_pillow_deterministic"


def p(x: float, y: float, z: float = 0.0, rotation: int = 0) -> tuple[int, int]:
    # Local world coordinates: x width, y depth, z height. Rotation is clockwise.
    if rotation == 1:
        x, y = y, 1.0 - x
    elif rotation == 2:
        x, y = 1.0 - x, 2.0 - y
    elif rotation == 3:
        x, y = 2.0 - y, x
    return (round(PIVOT[0] + 128.0 * (x - y)), round(PIVOT[1] + 64.0 * (x + y) - Z_SCALE * z))


def poly(draw: ImageDraw.ImageDraw, points, fill, outline=None, width=1):
    draw.polygon(points, fill=fill)
    if outline:
        draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def render(rotation: int, layer: str) -> Image.Image:
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if layer == "shadow":
        # Shadow extends less than 0.15m beyond the logical footprint.
        poly(draw, [p(-0.07, -0.04, 0, rotation), p(0.99, -0.04, 0, rotation),
                    p(1.07, 2.04, 0, rotation), p(0.01, 2.04, 0, rotation)],
             (18, 22, 28, 92))
        return image

    # Back posts and top cap, all within the 0.92m x 1.92m body envelope.
    x0, x1 = 0.04, 0.96
    y0, y1 = 0.04, 1.96
    z0, z1 = 0.0, 1.40
    top = [p(x0, y0, z1, rotation), p(x1, y0, z1, rotation),
           p(x1, y1, z1, rotation), p(x0, y1, z1, rotation)]
    right = [p(x1, y0, z0, rotation), p(x1, y1, z0, rotation),
             p(x1, y1, z1, rotation), p(x1, y0, z1, rotation)]
    left = [p(x0, y0, z0, rotation), p(x0, y1, z0, rotation),
            p(x0, y1, z1, rotation), p(x0, y0, z1, rotation)]
    poly(draw, left, (92, 66, 45, 255), (45, 33, 25, 255), 2)
    poly(draw, right, (122, 86, 53, 255), (45, 33, 25, 255), 2)
    poly(draw, top, (172, 124, 70, 255), (65, 43, 26, 255), 2)

    # Three shelves and a warm onigiri display band on the E-facing long side.
    for z in (0.35, 0.72, 1.09):
        shelf = [p(x0, y0, z, rotation), p(x1, y0, z, rotation),
                 p(x1, y1, z, rotation), p(x0, y1, z, rotation)]
        poly(draw, shelf, (142, 96, 54, 255), (61, 40, 25, 255), 2)
    front_y = y0
    band = [p(x0 + 0.02, front_y, 0.92, rotation), p(x1 - 0.02, front_y, 0.92, rotation),
            p(x1 - 0.02, front_y, 1.12, rotation), p(x0 + 0.02, front_y, 1.12, rotation)]
    poly(draw, band, (220, 145, 48, 255), (94, 52, 20, 255), 2)
    # Minimal deterministic rice triangles; visual only, no runtime product dependency.
    for i in range(6):
        cx = x0 + 0.12 + i * 0.14
        tri = [p(cx - 0.045, front_y - 0.01, 1.04, rotation),
               p(cx, front_y - 0.01, 1.16, rotation),
               p(cx + 0.045, front_y - 0.01, 1.04, rotation)]
        poly(draw, tri, (246, 239, 214, 255), (120, 84, 52, 255), 1)
    return image


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    rotations = {}
    for rotation in range(4):
        body_name = f"shelf_onigiri_{rotation}_body.png"
        shadow_name = f"shelf_onigiri_{rotation}_shadow.png"
        render(rotation, "body").save(ROOT / body_name, "PNG", optimize=False, compress_level=9)
        render(rotation, "shadow").save(ROOT / shadow_name, "PNG", optimize=False, compress_level=9)
        # Slot anchors follow the 3 rows x 12 positions capacity layout, on the E-facing side.
        slots = {}
        for row, z in enumerate((0.42, 0.78, 1.14)):
            for col in range(12):
                x = 0.08 + col * (0.76 / 11)
                slots[f"row{row}_item{col}"] = list(p(x, 0.01, z, rotation))
        rotations[str(rotation)] = {
            "canvas_px": list(SIZE),
            "anchor_px": list(PIVOT),
            "layers": {"body": body_name, "shadow": shadow_name},
            "slot_anchors_px": slots,
            "selection_polygon_px": [list(p(-0.5, -0.5, 0, rotation)), list(p(0.5, -0.5, 0, rotation)),
                                      list(p(0.5, 1.5, 0, rotation)), list(p(-0.5, 1.5, 0, rotation))],
            "sorting_anchor_px": list(PIVOT),
        }
        for name in (body_name, shadow_name):
            file_path = ROOT / name
            write_json(file_path.with_suffix(".provenance.json"), {
                "asset": name,
                "generator": "regenerate_shelf_onigiri.py",
                "generator_mode": "deterministic_pillow",
                "seed": SEED,
                "projection_id": PROJECTION,
                "source_px_per_tile": [256, 128],
                "sha256": sha256(file_path),
                "runtime_approved": False,
            })

    manifest = {
        "manifest_version": 1,
        "visual_id": "shelf_onigiri_candidate_v1",
        "fixture_type_id": "shelf_onigiri",
        "projection_id": PROJECTION,
        "world_units_per_tile": 1,
        "source_px_per_tile_diamond": [256, 128],
        "footprint": {"w": 1, "h": 2},
        "dimensions_m": {"width": 0.92, "depth": 1.92, "height": 1.40},
        "rotations": rotations,
    }
    write_json(ROOT / "shelf_onigiri.visual.json", manifest)
    write_json(ROOT / "shelf_onigiri_candidate_v1.provenance.json", {
        "asset_id": "shelf_onigiri_candidate_v1",
        "runtime_approved": False,
        "generator": "regenerate_shelf_onigiri.py",
        "generator_mode": "deterministic_pillow",
        "seed": SEED,
        "projection_id": PROJECTION,
        "source_px_per_tile": [256, 128],
        "dimensions_m": {"width": 0.92, "depth": 1.92, "height": 1.40},
        "access_edge": "E",
        "files": {name: sha256(ROOT / name) for rotation in range(4) for name in (
            f"shelf_onigiri_{rotation}_body.png", f"shelf_onigiri_{rotation}_shadow.png")},
    })


if __name__ == "__main__":
    main()
