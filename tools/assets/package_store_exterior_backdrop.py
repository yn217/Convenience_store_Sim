"""Fit a generated, combined landscape image to the two far-wall angles.

The source is retained. A small vertical shear on each half aligns the two
visible planting edges while keeping tree trunks and fence posts vertical.
"""
from pathlib import Path
import hashlib
import json
import math

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = "store_exterior_backdrop_v1"
SOURCE = ROOT / "assets/source/background" / ASSET_ID / "original.png"
DEST = ROOT / "assets/generated/backgrounds" / ASSET_ID


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def edge_line(alpha: np.ndarray, left: bool) -> tuple[float, float]:
    height, width = alpha.shape
    lo, hi = (0.06, 0.46) if left else (0.54, 0.94)
    samples = []
    for x in range(int(lo * width), int(hi * width), max(1, width // 150)):
        ys = np.flatnonzero(alpha[:, x] >= 128)
        if ys.size:
            samples.append((x, ys[-1]))
    if len(samples) < 20:
        raise ValueError("Background does not contain enough opaque ground-edge samples")
    xy = np.asarray(samples)
    slope, intercept = np.polyfit(xy[:, 0], xy[:, 1], 1)
    return float(slope), float(intercept)


def intersection(left: tuple[float, float], right: tuple[float, float]) -> tuple[float, float]:
    x = (right[1] - left[1]) / (left[0] - right[0])
    return x, left[0] * x + left[1]


def main() -> None:
    original = Image.open(SOURCE).convert("RGBA")
    width, height = original.size
    alpha = np.asarray(original.getchannel("A"))
    source_left, source_right = edge_line(alpha, True), edge_line(alpha, False)
    source_apex = intersection(source_left, source_right)
    left_shear = -0.5 - source_left[0]
    right_shear = 0.5 - source_right[0]
    ys, xs = np.nonzero(alpha)
    shifts = np.where(xs < source_apex[0], left_shear, right_shear) * (xs - source_apex[0])
    top_padding = max(0, int(math.ceil(-float(np.min(ys + shifts)))) + 2)
    output_size = (width, height + top_padding)

    def sheared(shear: float) -> Image.Image:
        # Forward y_out = y_src + shear*(x-apex_x) + top_padding.
        inverse = (1.0, 0.0, 0.0, -shear, 1.0, shear * source_apex[0] - top_padding)
        return original.transform(output_size, Image.Transform.AFFINE, inverse, resample=Image.Resampling.BICUBIC)

    split = round(source_apex[0])
    left_image, right_image = sheared(left_shear), sheared(right_shear)
    result = Image.new("RGBA", output_size)
    result.paste(left_image.crop((0, 0, split, output_size[1])), (0, 0))
    result.paste(right_image.crop((split, 0, width, output_size[1])), (split, 0))
    result_alpha = np.asarray(result.getchannel("A"))
    final_left, final_right = edge_line(result_alpha, True), edge_line(result_alpha, False)
    final_apex = intersection(final_left, final_right)
    if abs(final_left[0] + 0.5) > 0.01 or abs(final_right[0] - 0.5) > 0.01:
        raise ValueError(f"Corrected scenery edges are not aligned: {final_left[0]}, {final_right[0]}")
    DEST.mkdir(parents=True, exist_ok=True)
    result.save(DEST / f"{ASSET_ID}.png", optimize=True)
    bbox = result.getchannel("A").getbbox()
    corners = [int(result_alpha[y, x]) for x, y in [(0, 0), (width - 1, 0), (0, output_size[1] - 1), (width - 1, output_size[1] - 1)]]
    spec = {
        "manifest_version": 1,
        "asset_id": ASSET_ID,
        "category": "static_screen_space_exterior_background",
        "view_direction": "two far-wall edges in iso2x_v1, camera-facing composite",
        "world_width": None,
        "world_depth": None,
        "world_height": None,
        "render_width_px": width,
        "render_height_px": output_size[1],
        "pivot_x": round(final_apex[0], 3),
        "pivot_y": round(final_apex[1], 3),
        "anchor_type": "behind_far_wall_corner",
        "placement_offset": [0, 0, 0],
        "occlusion_group": "non_interactive_backdrop_before_store",
        "sort_key": "BackdropLayer_before_store_world",
        "asset_variant": "combined_v_green_trees_sakura_hedges_flowers_fence",
        "source_file": f"assets/source/background/{ASSET_ID}/original.png",
        "runtime_fit": {
            "uniform_aspect_preserved": True,
            "tile_size_alignment_required": False,
            "anchor": "projected north/west wall junction, 0.9m below the wall top so the footing is occluded",
            "source_apex_px": [round(final_apex[0], 3), round(final_apex[1], 3)],
            "edge_slopes": [final_left[0], final_right[0]],
        },
        "alpha_bbox_px": list(bbox) if bbox else None,
        "corner_alpha": corners,
    }
    write_json(DEST / f"{ASSET_ID}.visual.json", spec)
    provenance = {
        "asset_id": ASSET_ID,
        "source_type": "ai_generated",
        "tool": "built-in image_gen via image-generation subagent",
        "generation_id": "exec-146ca07d-6c03-4957-8b4f-957826faaed8",
        "prompt": "One transparent combined scenery backdrop for a Japanese convenience-store management game, using the supplied mockup as style reference and a generated +/-0.5 wall-edge guide for geometry. Green trees, pink sakura, hedges, flowers and a low fence follow the two far store edges in a peaked V; leave the store interior and foreground transparent; no store, people, cars, road, text, signage or UI. Tree trunks and fence posts vertical.",
        "source_file": spec["source_file"],
        "original_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "packaging_script": "tools/assets/package_store_exterior_backdrop.py",
        "operations": ["piecewise vertical affine shears around the planting-edge apex, preserving vertical stems and aligning each edge to the game's +/-0.5 wall slopes"],
        "canvas_px": list(output_size),
        "source_edge_slopes": [source_left[0], source_right[0]],
        "output_edge_slopes": [final_left[0], final_right[0]],
        "apex_px": spec["runtime_fit"]["source_apex_px"],
        "alpha_range": list(result.getchannel("A").getextrema()),
        "alpha_bbox_px": list(bbox) if bbox else None,
        "corner_alpha": corners,
        "limitations": [
            "This combined static image is a backdrop; tree size is not tied to world tiles.",
            "The generated alpha edges contain some bright glints and need in-game visual review.",
            "This variant shows spring sakura; other seasons require separate artwork.",
        ],
    }
    write_json(DEST / "PROVENANCE.json", provenance)
    print(json.dumps({"size": list(output_size), "source_slopes": provenance["source_edge_slopes"],
                      "output_slopes": provenance["output_edge_slopes"], "apex_px": provenance["apex_px"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
