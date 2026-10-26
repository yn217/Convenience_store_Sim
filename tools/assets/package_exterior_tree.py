"""Package approved imagegen tree at iso2x_v1 scale; no creative repainting."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET = "green_street_tree_v1"
OUT = ROOT / "assets/generated/props" / ASSET
SOURCE = ROOT / "assets/source/exterior" / ASSET / "source.png"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    src = Image.open(SOURCE).convert("RGBA")
    # Ground point measured at trunk centre (649, 1200) in the generated source.
    # Uniform resampling only, retaining aspect ratio and alpha.
    body = src.resize((640, 640), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (720, 720))
    canvas.alpha_composite(body, (29, 27))
    canvas.save(OUT / f"{ASSET}_0_body.png")
    anchor = [360, 639]
    rotation = {
        "canvas_px": [720, 720], "anchor_px": anchor,
        "layers": {"body": f"{ASSET}_0_body.png"},
        "sorting_anchor_px": anchor, "slot_anchors_px": {},
        "selection_polygon_px": [[360, 610], [432, 646], [360, 682], [288, 646]],
    }
    manifest = {
        "manifest_version": 1, "visual_id": ASSET, "fixture_type_id": ASSET,
        "projection_id": "iso2x_v1", "world_units_per_tile": 1,
        "source_px_per_tile_diamond": [256, 128],
        "footprint": {"w": 1, "h": 1},
        "dimensions_m": {"width": 2.8, "depth": 2.8, "height": 3.5},
        "rotations": {str(i): rotation for i in range(4)},
    }
    (OUT / f"{ASSET}.visual.json").write_text(json.dumps(manifest, indent=2) + "\n")
    assert canvas.mode == "RGBA" and canvas.getextrema()[3] == (0, 255)
    assert canvas.getpixel(tuple(anchor))[3] > 180
    assert not any(canvas.getpixel((x, 0))[3] for x in range(720))
    print(f"Validated {ASSET}: RGBA 720x720, anchor {anchor}, transparent border")


if __name__ == "__main__":
    main()

