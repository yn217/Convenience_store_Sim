"""Calibrate a generated landscape strip to the game's 2:1 projected edge.

The source is retained unchanged. A small affine vertical shear corrects the
measured ground-edge slope; a horizontal mirror makes it follow a north/south
store edge. No perspective correction or non-uniform scaling is applied.
"""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = "exterior_landscape_panel_v1"
SOURCE = ROOT / "assets/source/background" / ASSET_ID / "original.png"
DEST = ROOT / "assets/generated/backgrounds" / ASSET_ID
TARGET_SLOPE = -0.5
SOURCE_PX_PER_WORLD_EDGE_M = 128.0


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def measure_lower_edge(alpha: np.ndarray) -> tuple[float, float]:
    xs = np.arange(0, alpha.shape[1], max(1, alpha.shape[1] // 200))
    samples = []
    for x in xs:
        ys = np.flatnonzero(alpha[:, x] >= 128)
        if ys.size:
            samples.append((float(x), float(ys[-1])))
    xvals, yvals = np.asarray(samples).T
    slope, intercept = np.polyfit(xvals, yvals, 1)
    return float(slope), float(intercept)


def main() -> None:
    original = Image.open(SOURCE).convert("RGBA")
    alpha = np.asarray(original.getchannel("A"))
    measured_slope, measured_intercept = measure_lower_edge(alpha)
    width, height = original.size
    shear = TARGET_SLOPE - measured_slope
    # Keep the rightmost endpoint fixed and add canvas only on the lower-left side.
    offset_y = max(0.0, -shear * width)
    output_height = int(np.ceil(height + offset_y))
    # PIL maps output pixels to source pixels: y_src = y_out - shear*x + shear*width.
    transform = (1.0, 0.0, 0.0, -shear, 1.0, shear * width)
    calibrated = original.transform(
        (width, output_height), Image.Transform.AFFINE, transform,
        resample=Image.Resampling.BICUBIC,
    )
    DEST.mkdir(parents=True, exist_ok=True)
    north = calibrated.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    calibrated.save(DEST / f"{ASSET_ID}_west.png", optimize=True)
    north.save(DEST / f"{ASSET_ID}_north.png", optimize=True)

    world_length = width / SOURCE_PX_PER_WORLD_EDGE_M
    # Source canvas includes the diagonal ground edge; the tree crown height is a
    # visual envelope, recorded separately from its along-edge dimension.
    manifest = {
        "manifest_version": 1,
        "asset_id": ASSET_ID,
        "category": "static_exterior_background",
        "view_direction": "iso2x_v1 north_edge; horizontal mirror of generated south-edge strip",
        "projection_id": "iso2x_v1",
        "world_width": round(world_length, 3),
        "world_depth": 0.0,
        "world_height": 4.0,
        "render_width_px": north.width,
        "render_height_px": north.height,
        "pivot_x": north.width - 1,
        "pivot_y": north.height - 1,
        "anchor_type": "north_right_or_west_lower_endpoint_ground_contact",
        "placement_offset": [0, -5.5, 0],
        "occlusion_group": "behind_store_far_wall",
        "sort_key": "background_before_store",
        "asset_variant": "combined_green_and_sakura_perimeter_strip",
        "source_scale_px_per_world_edge_m": SOURCE_PX_PER_WORLD_EDGE_M,
        "ground_edge": {
            "source_slope_px_per_px": measured_slope,
            "source_intercept_px": measured_intercept,
            "target_slope_px_per_px": TARGET_SLOPE,
            "affine_vertical_shear": shear,
        },
        "source_file": "assets/source/background/exterior_landscape_panel_v1/original.png",
        "render_variants": {
            "north": f"assets/generated/backgrounds/{ASSET_ID}/{ASSET_ID}_north.png",
            "west": f"assets/generated/backgrounds/{ASSET_ID}/{ASSET_ID}_west.png",
        },
        "packaging_script": "tools/assets/package_exterior_landscape_panel.py",
    }
    write_json(DEST / f"{ASSET_ID}.visual.json", manifest)
    provenance = {
        "asset_id": ASSET_ID,
        "source_type": "ai_generated",
        "tool": "built-in image_gen",
        "generation_id": "exec-ca296fc3-1fea-48cc-a446-c9020f849593",
        "source_file": manifest["source_file"],
        "original_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "operations": [
            "affine vertical shear to project the measured ground edge to iso2x_v1 slope -0.5 while preserving vertical stems",
            "horizontal mirror to align with the north store edge; no text or directional signage is present",
        ],
        "source_canvas_px": [width, height],
        "output_canvas_px": [north.width, north.height],
        "source_ground_edge_slope": measured_slope,
        "target_ground_edge_slope": TARGET_SLOPE,
        "alpha_range": list(north.getchannel("A").getextrema()),
        "limitations": [
            "The generated foliage has painterly alpha-edge variation; inspect against both dark and light surroundings.",
            "One generated strip covers 13.86 world metres; store-size variants need additional edge coverage.",
            "This is a static scenery backdrop and must remain behind the store floor, walls, and input layers.",
        ],
    }
    write_json(DEST / "PROVENANCE.json", provenance)
    print(json.dumps({"source_size": [width, height], "source_slope": measured_slope,
                      "target_slope": TARGET_SLOPE, "output_size": [calibrated.width, calibrated.height],
                      "world_length_m": world_length}, ensure_ascii=False))


if __name__ == "__main__":
    main()
