"""Package the generated long tree bed with a measured +0.5 iso ground edge."""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = "roadside_greenery_v2"
SOURCE = ROOT / "assets/source/background" / ASSET_ID / "side_strip_v1.png"
DEST = ROOT / "assets/generated/backgrounds" / ASSET_ID


def edge_samples(alpha: np.ndarray) -> list[tuple[int, int]]:
    height, width = alpha.shape
    samples = []
    for x in range(width):
        ys = np.flatnonzero(alpha[:, x] >= 220)
        if ys.size:
            samples.append((x, int(ys[-1])))
    if len(samples) < 30:
        raise ValueError("not enough planter-edge samples")
    return samples


def edge_line(samples: list[tuple[int, int]]) -> tuple[float, float]:
    points = np.asarray(samples, dtype=np.float64)
    # Robustly reject the occasional leaf/drop-shadow tail without ignoring the planted edge.
    slope, intercept = np.polyfit(points[:, 0], points[:, 1], 1)
    residual = np.abs(points[:, 1] - (slope * points[:, 0] + intercept))
    keep = residual <= max(8.0, float(np.percentile(residual, 75)))
    return tuple(float(v) for v in np.polyfit(points[keep, 0], points[keep, 1], 1))


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    width, height = source.size
    alpha = np.asarray(source.getchannel("A"))
    source_slope, source_intercept = edge_line(edge_samples(alpha)[::max(1, width // 220)])
    shear = 0.5 - source_slope
    xs = np.nonzero(alpha)[1]
    ys = np.nonzero(alpha)[0]
    center_x = (width - 1) * 0.5
    vertical_shift = shear * (xs - center_x)
    pad_top = max(0, int(np.ceil(-float(vertical_shift.min()))) + 3)
    pad_bottom = max(0, int(np.ceil(float(vertical_shift.max()))) + 3)
    output_size = (width, height + pad_top + pad_bottom)
    # This affine vertical shear aligns the authored ground edge while keeping trunks vertical.
    inverse = (1.0, 0.0, 0.0, -shear, 1.0, shear * center_x - pad_top)
    result = source.transform(output_size, Image.Transform.AFFINE, inverse, resample=Image.Resampling.BICUBIC)
    out_alpha = np.asarray(result.getchannel("A"))
    samples = edge_samples(out_alpha)
    output_slope, output_intercept = edge_line(samples[::max(1, width // 220)])
    if abs(output_slope - 0.5) > 0.02:
        raise ValueError(f"wrong projected planter-edge slope: {output_slope}")
    ground_px = [round(center_x, 3), round(output_slope * center_x + output_intercept, 3)]
    left_y = round(output_intercept, 3)
    right_y = round(output_slope * (width - 1) + output_intercept, 3)
    ground_start = [int(samples[0][0]), int(samples[0][1])]
    ground_end = [int(samples[-1][0]), int(samples[-1][1])]

    DEST.mkdir(parents=True, exist_ok=True)
    result.save(DEST / f"{ASSET_ID}.png", optimize=True)
    bbox = result.getchannel("A").getbbox()
    metadata = {
        "manifest_version": 1,
        "asset_id": ASSET_ID,
        "category": "static_world_anchored_exterior_vegetation_strip",
        "view_direction": "iso2x_v1 continuous one-edge planting strip",
        "render_width_px": width,
        "render_height_px": output_size[1],
        "ground_anchor_px": ground_px,
        "ground_edge_endpoints_px": [ground_start, ground_end],
        "anchor_type": "planter_ground_contact_at_world_side_anchor_z0",
        "sort_key": "vegetation_before_store_and_wall_occlusion",
        "runtime_fit": {
            "uniform_scale_only": True,
            "world_edge_length": "full_store_side_plus_1m_overhang",
            "source_ground_edge_slope": output_slope,
            "target_edge_slopes": [-0.5, 0.5],
            "runtime_vertical_shear": 0.5 - output_slope,
            "roots_hidden_by_wall": True,
        },
        "source_file": f"assets/source/background/{ASSET_ID}/{SOURCE.name}",
        "alpha_bbox_px": list(bbox) if bbox else None,
    }
    provenance = {
        "asset_id": ASSET_ID,
        "source_type": "ai_generated",
        "tool": "built-in image_gen via image-generation subagent",
        "generation_id": "exec-6dc3588e-7135-4c78-8f10-972f660e4805",
        "prompt": "Transparent long straight isometric garden strip: dense mature green trees, layered shrubs, pink and white flowers, narrow stone planter, vertical trunks, no pavement, lamp, signage, wall, people or text.",
        "source_file": metadata["source_file"],
        "original_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "packaging_script": "tools/assets/package_roadside_greenery_v2.py",
        "operations": ["small measured vertical affine shear to align the planting ground edge to the +/-0.5 isometric wall slope; uniform runtime scaling"],
        "source_ground_edge_slope": source_slope,
        "output_ground_edge_slope": output_slope,
        "limitations": ["Thin generated color fringe remains at a few extreme silhouette pixels; inspect at game scale.", "Static spring landscape; the wall occludes its planter roots."],
    }
    write_json(DEST / f"{ASSET_ID}.visual.json", metadata)
    write_json(DEST / "PROVENANCE.json", provenance)
    print(json.dumps({"size": output_size, "source_slope": source_slope, "output_slope": output_slope, "ground_anchor_px": ground_px, "ground_edge_endpoints_px": [ground_start, ground_end]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
