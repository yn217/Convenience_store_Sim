"""Package the generated tall-tree V backdrop with measured +/-0.5 ground-edge slopes."""
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSET_ID = "store_exterior_backdrop_v2"
SOURCE = ROOT / "assets/source/background" / ASSET_ID / "corner_v1.png"
DEST = ROOT / "assets/generated/backgrounds" / ASSET_ID


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
    metadata = {
        "manifest_version": 1,
        "asset_id": ASSET_ID,
        "category": "static_world_anchored_exterior_vegetation",
        "view_direction": "iso2x_v1 rear V backdrop with tall trees",
        "render_width_px": width,
        "render_height_px": size[1],
        "ground_apex_px": [round(out_apex[0], 3), round(out_apex[1], 3)],
        "left_ground_endpoint_px": [0, round(out_left[0] * 0 + out_left[1], 3)],
        "right_ground_endpoint_px": [width - 1, round(out_right[0] * (width - 1) + out_right[1], 3)],
        "anchor_type": "behind_far_corner_ground_z0",
        "sort_key": "vegetation_before_opaque_far_wall",
        "runtime_fit": {
            "uniform_scale_only": True,
            "world_root_anchor": "(-0.5 - offset, -0.5 - offset, 0)",
            "separate_edge_checks": True,
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
