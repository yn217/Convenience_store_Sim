"""Package the back-wall cooler door (2026-11-14) as the prop `wall_cooler_depth_v1` for WallDecor.

Source: F:/Stable Diffusion/game-assets/depth_wallcooler_20261114 (wall.py model -> Blender depth -> ComfyUI Z-Image, seed
202; gen_wall.py). Scaled and anchored like the depth fixtures (tools/assets/package_depth_fixtures.py): a 1x1
footprint, the anchor at the tile centre. Rotation 0 shows the glass front facing south (the north wall), 1 its mirror
facing east (the west wall); 2 and 3 repeat them (the back stands against the wall and is never seen).

Run: python tools/assets/package_wall_cooler.py
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

import package_depth_fixtures as p

SRC = Path("F:/Stable Diffusion/game-assets/depth_wallcooler_20261114")
ID = "wall_cooler_depth_v1"
OUT = p.ROOT / "assets/generated/props" / ID


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    boxes = json.loads((SRC / "boxes.json").read_text())["wall_cooler"]
    tgt, S = p.frame(boxes)
    k = p.PX_PER_M * S / p.RENDER
    rots = {}
    for r in range(4):
        yaw = 0 if r % 2 == 0 else 90
        src = Image.open(SRC / "final" / f"wall_cooler_s202_y{yaw}.png").convert("RGBA")
        bbox = src.getbbox()
        body = src.crop(bbox)
        size = (round(body.width * k), round(body.height * k))
        body = body.resize(size, Image.Resampling.LANCZOS)
        # y90 is the mirror of y0: its anchor is the mirrored point of the y0 projection of the origin.
        origin = p.project((0, 0, 0), tgt, S, 0)
        if yaw == 90:
            origin = np.array([p.RENDER - origin[0], origin[1]])
        anchor = (origin - np.array(bbox[:2])) * k + p.MARGIN
        canvas = (size[0] + 2 * p.MARGIN, size[1] + 2 * p.MARGIN)
        out = Image.new("RGBA", canvas)
        out.alpha_composite(body, (p.MARGIN, p.MARGIN))
        name = f"{ID}_{r}_body.png"
        out.save(OUT / name)
        a = [round(float(anchor[0]), 2), round(float(anchor[1]), 2)]
        rots[str(r)] = {"canvas_px": list(canvas), "anchor_px": a, "layers": {"body": name}, "sorting_anchor_px": a}
    manifest = {"manifest_version": 1, "visual_id": ID, "fixture_type_id": ID, "projection_id": "iso2x_v1", "world_units_per_tile": 1,
                "source_px_per_tile_diamond": [256, 128], "footprint": {"w": 1, "h": 1}, "dimensions_m": {"width": 0.92, "depth": 0.92, "height": 2.0},
                "rotations": rots}
    (OUT / f"{ID}.visual.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(ID, rots["0"]["canvas_px"], rots["0"]["anchor_px"])


if __name__ == "__main__":
    main()
