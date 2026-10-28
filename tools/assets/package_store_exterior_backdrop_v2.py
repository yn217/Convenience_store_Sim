"""Package the generated tall-tree V backdrop with measured +/-0.5 ground-edge slopes."""
from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = "store_exterior_backdrop_v2"
SOURCE = ROOT / "assets/source/background" / ASSET_ID / "corner_v1.png"
DEST = ROOT / "assets/generated/backgrounds" / ASSET_ID
MAX_STORE_WIDTH_M = 20.0
MAX_STORE_HEIGHT_M = 16.0
GROUND_OFFSET_M = 0.45
HALF_TILE_W = 64.0
HALF_TILE_H = 32.0
Z_PX_PER_M = 78.38367177


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def edge_line(alpha: np.ndarray, left: bool) -> tuple[float, float]:
    height, width = alpha.shape
    lo, hi = (0.04, 0.46) if left else (0.54, 0.96)
    samples = []
    for x in range(int(lo * width), int(hi * width), max(1, width // 180)):
        ys = np.flatnonzero(alpha[:, x] >= 160)
        if ys.size:
            samples.append((x, ys[-1]))
    if len(samples) < 20:
        raise ValueError("not enough ground-edge samples")
    xy = np.asarray(samples)
    slope, intercept = np.polyfit(xy[:, 0], xy[:, 1], 1)
    return float(slope), float(intercept)


def intersection(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
    x = (b[1] - a[1]) / (a[0] - b[0])
    return x, a[0] * x + a[1]


def main() -> None:
    original = Image.open(SOURCE).convert("RGBA")
    width, height = original.size
    alpha = np.asarray(original.getchannel("A"))
    source_left, source_right = edge_line(alpha, True), edge_line(alpha, False)
    apex = intersection(source_left, source_right)
    shears = (-0.5 - source_left[0], 0.5 - source_right[0])
    ys, xs = np.nonzero(alpha)
    shifts = np.where(xs < apex[0], shears[0], shears[1]) * (xs - apex[0])
    padding = max(0, int(np.ceil(-float(np.min(ys + shifts)))) + 2)
    size = (width, height + padding)

    def shear_image(amount: float) -> Image.Image:
        # Preserve vertical trunks; correct the planted edge only around the measured V apex.
        inverse = (1.0, 0.0, 0.0, -amount, 1.0, amount * apex[0] - padding)
        return original.transform(size, Image.Transform.AFFINE, inverse, resample=Image.Resampling.BICUBIC)

    split = round(apex[0])
    left, right = shear_image(shears[0]), shear_image(shears[1])
    result = Image.new("RGBA", size)
    result.paste(left.crop((0, 0, split, size[1])), (0, 0))
    result.paste(right.crop((split, 0, width, size[1])), (split, 0))
    out_alpha = np.asarray(result.getchannel("A"))
    out_left, out_right = edge_line(out_alpha, True), edge_line(out_alpha, False)
    out_apex = intersection(out_left, out_right)
    if abs(out_left[0] + 0.5) > 0.02 or abs(out_right[0] - 0.5) > 0.02:
        raise ValueError(f"wrong projected ground-edge slopes: {out_left[0]}, {out_right[0]}")

    DEST.mkdir(parents=True, exist_ok=True)
    result.save(DEST / f"{ASSET_ID}.png", optimize=True)
    bbox = result.getchannel("A").getbbox()
    max_left_run_px = math.hypot(HALF_TILE_W, HALF_TILE_H) * (MAX_STORE_HEIGHT_M + 2.0 * GROUND_OFFSET_M)
    max_right_run_px = math.hypot(HALF_TILE_W, HALF_TILE_H) * (MAX_STORE_WIDTH_M + 2.0 * GROUND_OFFSET_M)
    left_run_px = math.hypot(out_apex[0], out_left[1] - out_apex[1])
    right_run_px = math.hypot(width - 1 - out_apex[0], out_right[0] * (width - 1) + out_right[1] - out_apex[1])
    fixed_scale = max(max_left_run_px / left_run_px, max_right_run_px / right_run_px)
    canopy_height_m = (out_apex[1] - bbox[1]) * fixed_scale / Z_PX_PER_M
    projected_tile_run = math.hypot(HALF_TILE_W, HALF_TILE_H)
    left_arm_m = left_run_px * fixed_scale / projected_tile_run
    right_arm_m = right_run_px * fixed_scale / projected_tile_run
    metadata = {
        "manifest_version": 1,
        "asset_id": ASSET_ID,
        "category": "static_world_anchored_exterior_vegetation",
        "view_direction": "iso2x_v1 rear V backdrop with tall trees",
        "world_width": round(max(left_arm_m, right_arm_m), 3),
        "world_width_by_arm_m": {"left": round(left_arm_m, 3), "right": round(right_arm_m, 3)},
        "world_depth": GROUND_OFFSET_M,
        "world_height": round(canopy_height_m, 3),
        "render_width_px": width,
        "render_height_px": size[1],
        "ground_apex_px": [round(out_apex[0], 3), round(out_apex[1], 3)],
        "pivot_x": round(out_apex[0], 3),
        "pivot_y": round(out_apex[1], 3),
        "left_ground_endpoint_px": [0, round(out_left[0] * 0 + out_left[1], 3)],
        "right_ground_endpoint_px": [width - 1, round(out_right[0] * (width - 1) + out_right[1], 3)],
        "anchor_type": "behind_far_corner_ground_z0",
        "placement_offset": [-GROUND_OFFSET_M, -GROUND_OFFSET_M, 0.0],
        "occlusion_group": "rear_wall_vegetation",
        "sort_key": "behind_store_wall_occlusion_overlay",
        "asset_variant": "v2_fixed_world_height",
        "runtime_fit": {
            "uniform_scale_only": True,
            "world_root_anchor": "(-0.5 - 0.45, -0.5 - 0.45, 0)",
            "separate_edge_checks": True,
            "scale_policy": "fixed from the 20x16 maximum supported footprint; smaller stores retain the same world tree height and show surplus planting past their wall endpoints",
            "fixed_world_height_m": round(canopy_height_m, 3),
            "max_supported_store_dimensions_m": [MAX_STORE_WIDTH_M, MAX_STORE_HEIGHT_M],
            "edge_slopes": [out_left[0], out_right[0]],
            "root_and_planter_occlusion": "opaque far wall overlay",
        },
        "source_file": f"assets/source/background/{ASSET_ID}/{SOURCE.name}",
        "alpha_bbox_px": list(bbox) if bbox else None,
        "corner_alpha": [int(out_alpha[y, x]) for x, y in [(0, 0), (width - 1, 0), (0, size[1] - 1), (width - 1, size[1] - 1)]],
    }
    write_json(DEST / f"{ASSET_ID}.visual.json", metadata)
    provenance = {
        "asset_id": ASSET_ID,
        "source_type": "ai_generated",
        "tool": "built-in image_gen via image-generation subagents",
        "generation_id": "exec-d4d22a1c-a9c3-448a-8c8b-4e2762053adf",
        "prompt": "Transparent isometric V-shaped rear landscaping, apex at upper center with two branches extending toward lower left and lower right. Tall trees above a 2.6 m store wall, dense shrubs and flowers, distinct stone planter ground-contact line. No store, wall, roads, UI, people or text.",
        "source_file": metadata["source_file"],
        "original_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "packaging_script": "tools/assets/package_store_exterior_backdrop_v2.py",
        "operations": ["independent small vertical edge shears around V apex to align both ground edges to the game's +/-0.5 isometric slopes; no non-uniform scaling"],
        "source_edge_slopes": [source_left[0], source_right[0]],
        "output_edge_slopes": [out_left[0], out_right[0]],
        "limitations": ["Static spring vegetation; roots are hidden by the game's opaque back wall.", "World scale is evaluated by V branch endpoints at runtime."],
    }
    write_json(DEST / "PROVENANCE.json", provenance)
    print(json.dumps({"size": size, "source_slopes": provenance["source_edge_slopes"], "output_slopes": provenance["output_edge_slopes"], "apex": metadata["ground_apex_px"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
