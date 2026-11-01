"""Apply one reference-derived transform to every combined shelf state.

This is an experiment: matching coordinates alone does not certify that image
generation preserved the fixture structure. Runtime approval is always false.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def threshold_bbox(image: Image.Image, threshold: int) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("image has no visible alpha at the selected threshold")
    return bbox


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--half", type=Path, required=True)
    parser.add_argument("--empty", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--alpha-threshold", type=int, default=8)
    args = parser.parse_args()
    if not 1 <= args.alpha_threshold <= 255:
        parser.error("alpha threshold must be between 1 and 255")

    paths = {"full": args.reference, "half": args.half, "empty": args.empty}
    images = {name: Image.open(path).convert("RGBA") for name, path in paths.items()}
    ref = images["full"]
    if any(image.size != ref.size for image in images.values()):
        raise ValueError("All source images must have the same canvas dimensions")

    bbox = threshold_bbox(ref, args.alpha_threshold)
    target = (38, 8, 403, 425)
    target_w, target_h = target[2] - target[0], target[3] - target[1]
    scale = min(target_w / (bbox[2] - bbox[0]), target_h / (bbox[3] - bbox[1]))
    size = (round(ref.width * scale), round(ref.height * scale))
    # Mirror the entire original canvas, not each state's bounding box.
    mirrored_ref_left = ref.width - bbox[2]
    offset = (target[0] - round(mirrored_ref_left * scale),
              target[1] - round(bbox[1] * scale))
    if offset[0] < 0 or offset[1] < 0 or offset[0] + size[0] > 442 or offset[1] + size[1] > 449:
        raise ValueError("reference transform would crop the source canvas")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    states = {}
    for name, image in images.items():
        original_bbox = threshold_bbox(image, args.alpha_threshold)
        alpha = image.getchannel("A").point(lambda value: 0 if value < args.alpha_threshold else value)
        image.putalpha(alpha)
        scaled = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT).resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (442, 449), (0, 0, 0, 0))
        canvas.alpha_composite(scaled, offset)
        output = args.out_dir / f"shelf_general_{name}_fixed_transform.png"
        canvas.save(output, optimize=True)
        states[name] = {"source": str(paths[name]), "source_bbox": list(original_bbox),
                        "output": output.name,
                        "output_bbox_alpha_nonzero": list(canvas.getchannel("A").getbbox()),
                        "output_bbox_alpha_threshold": list(threshold_bbox(canvas, args.alpha_threshold))}

    report = {"projection_id": "iso2x_v1", "footprint": [1, 2], "anchor_px": [285, 302],
              "target_canvas_px": [442, 449], "target_reference_bbox": list(target),
              "reference_bbox": list(bbox), "source_canvas_px": list(ref.size),
              "nominal_uniform_scale": scale,
              "effective_scale_xy_after_pixel_rounding": [size[0] / ref.width, size[1] / ref.height],
              "offset_px": list(offset), "flip_x": True,
              "alpha_threshold": args.alpha_threshold, "states": states,
              "runtime_approved": False,
              "note": "Shared transform is not proof of fixture or anchor correspondence."}
    (args.out_dir / "fixed_transform_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
