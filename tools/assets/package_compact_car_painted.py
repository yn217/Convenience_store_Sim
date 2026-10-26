"""Package the inspected generated car with uniform scale and measured ground pivot.

No perspective correction, background removal, recolouring or alpha modification.
Run from any directory: python tools/assets/package_compact_car_painted.py.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET = "compact_car_painted_v1"
SOURCE = ROOT / "assets/source/exterior" / ASSET / "original.png"
DEST = ROOT / "assets/generated/props" / ASSET


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    original = Image.open(SOURCE).convert("RGBA")
    # At 2x source scale: u=128(x-y), v=64(x+y)-156.76734354z.
    # Alpha >=200 isolates the opaque body from the existing faint contact shadow.
    body = original.getchannel("A").point(lambda a: 255 if a >= 200 else 0).getbbox()
    target_body_width = 128.0 * (1.65 + 3.8)
    scale = target_body_width / (body[2] - body[0])
    canvas = tuple(round(n * scale) for n in original.size)
    image = original.resize(canvas, Image.Resampling.LANCZOS)
    # Measured from the visible front/rear tyre contact points, not the bottom of the canvas.
    ground_original = (773.0, 690.0)
    pivot = [round(v * scale, 3) for v in ground_original]
    DEST.mkdir(parents=True, exist_ok=True)
    rotations = {}
    for rot, sprite in [(0, image), (1, image.transpose(Image.Transpose.FLIP_LEFT_RIGHT))]:
        name = f"{ASSET}_{rot}_body.png"
        sprite.save(DEST / name)
        anchor = pivot if rot == 0 else [round(canvas[0] - pivot[0], 3), pivot[1]]
        rotations[str(rot)] = {
            "canvas_px": list(canvas), "anchor_px": anchor,
            "sorting_anchor_px": anchor,
            "layers": {"body": name}, "slot_anchors_px": {},
        }
    manifest = {
        "manifest_version": 1, "visual_id": ASSET, "fixture_type_id": ASSET,
        "projection_id": "iso2x_v1", "world_units_per_tile": 1,
        "source_px_per_tile_diamond": [256, 128],
        "footprint": {"w": 2, "h": 4},
        "dimensions_m": {"width": 1.65, "depth": 3.8, "height": 1.45},
        "rotations": rotations,
        "asset_spec": {
            "asset_id": ASSET, "category": "parked_vehicle",
            "view_direction": "rot0 long axis y, nose toward +y; rot1 mirrored along x",
            "world_width": 1.65, "world_depth": 3.8, "world_height": 1.45,
            "render_width_px": canvas[0], "render_height_px": canvas[1],
            "pivot_x": pivot[0], "pivot_y": pivot[1], "anchor_type": "ground_footprint_center",
            "placement_offset": [0, 0, 0], "occlusion_group": "exterior_vehicle",
            "sort_key": "world_x+world_y", "asset_variant": "painted_white_v1",
            "runtime_approved_rotations": [0],
        },
    }
    write_json(DEST / f"{ASSET}.visual.json", manifest)
    alpha = image.getchannel("A")
    provenance = {
        "asset_id": ASSET, "source_type": "ai_generated",
        "tool": "built-in image_gen", "source_file": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "generation_id": "exec-9a3ecba7-6bc0-4da8-a6c2-54ff09df2ff1",
        "original_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "packaging_script": "tools/assets/package_compact_car_painted.py",
        "operations": ["uniform Lanczos downscale with nearest integer canvas rounding", "rot1 horizontal mirror"],
        "uniform_scale": scale, "original_canvas_px": list(original.size),
        "opaque_body_bbox_alpha_200": list(body), "target_body_projected_width_source_px": target_body_width,
        "original_ground_pivot_px": list(ground_original),
        "ground_pivot_method": "visible tyre contact positions and projected footprint centre; approximate manual measurement",
        "measured_original_edges": {
            "long_edge": {"from_px": [685, 936], "to_px": [1268, 652], "slope_dy_dx": -284 / 583, "ideal_slope": -0.5},
            "front_short_edge": {"from_px": [190, 758], "to_px": [690, 932], "slope_dy_dx": 174 / 500, "ideal_slope": 0.5},
        },
        "alpha_validation": {"mode": image.mode, "range": list(alpha.getextrema()), "corner_alpha": [alpha.getpixel(p) for p in [(0, 0), (canvas[0]-1, 0), (0, canvas[1]-1), (canvas[0]-1, canvas[1]-1)]], "nonzero_bbox": list(alpha.getbbox())},
        "limitations": [
            "Generated shape is not an exact orthographic 2:1 projection; measured edges deviate from ideal slopes.",
            "Width is calibrated to 1.65m plus 3.8m projected extent; no nonuniform shape correction was applied.",
            "Ground pivot is a manually measured approximation requiring runtime parking-bay inspection.",
            "rot1 mirrors baked sunlight and reflections; retained as a candidate, not approved for runtime.",
            "rot2 and rot3 have no supplied art and must be skipped by PropSprites.",
            "Faint generated contact-shadow alpha is preserved; no opaque background was introduced.",
        ],
    }
    write_json(DEST / "PROVENANCE.json", provenance)
    write_json(SOURCE.parent / "PROVENANCE.json", provenance)
    print(json.dumps({"canvas": canvas, "pivot": pivot, "scale": scale, "alpha": provenance["alpha_validation"]}))


if __name__ == "__main__":
    main()
