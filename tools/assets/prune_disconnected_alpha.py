"""Remove disconnected generated symbols from a review/runtime alpha PNG.

This is intentionally a narrow, explicit post-process for bust-up reaction
assets.  It keeps the largest connected foreground component and any other
component above a caller-provided area ratio.  The original ComfyUI render is
never modified; the derived PNG is the only output that may be replaced.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def prune(path: Path, output: Path, min_component_ratio: float) -> dict[str, int | str]:
    image = Image.open(path).convert("RGBA")
    rgba = np.array(image)
    alpha = rgba[:, :, 3]
    components, labels, stats, _ = cv2.connectedComponentsWithStats(
        (alpha > 32).astype(np.uint8), connectivity=8
    )
    if components <= 1:
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(output)
        return {"input": str(path), "output": str(output), "components": 0, "removed": 0}

    areas = stats[1:, cv2.CC_STAT_AREA]
    largest = int(areas.max())
    keep_labels = {idx + 1 for idx, area in enumerate(areas) if area >= largest * min_component_ratio}
    kept_mask = np.isin(labels, list(keep_labels))
    removed_mask = (labels > 0) & ~kept_mask
    result = rgba.copy()
    result[:, :, 3] = np.where(kept_mask, alpha, 0).astype(np.uint8)
    # Do not leave RGB data in removed pixels; this keeps downstream alpha
    # compositors from sampling the generated symbol's fringe.
    result[removed_mask, :3] = 0
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(result, "RGBA").save(output)
    return {
        "input": str(path),
        "output": str(output),
        "components": int(components - 1),
        "removed": int(components - 1 - len(keep_labels)),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", nargs="+", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--in-place", action="store_true")
    parser.add_argument("--min-component-ratio", type=float, default=0.05)
    args = parser.parse_args()
    if args.in_place and args.output_dir:
        parser.error("use either --in-place or --output-dir")
    for source in args.input:
        destination = source if args.in_place else args.output_dir / source.name
        print(prune(source, destination, args.min_component_ratio))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
