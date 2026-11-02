"""Remove a connected white background while preserving the original canvas.

This is a narrow fallback for white-background character renders when the
background-removal model produces an opaque result.  Only near-white pixels
connected to the image border are removed; enclosed white clothing/highlights
are retained.  The input is never modified.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def remove_background(source: Path, destination: Path) -> dict[str, int | str]:
    image = np.asarray(Image.open(source).convert("RGB")).astype(np.float32)
    minimum = image.min(axis=2)
    maximum = image.max(axis=2)
    near_white = (minimum >= 236) & ((maximum - minimum) <= 14)
    labels, count = ndimage.label(near_white)
    border_labels = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    background = np.isin(labels, list(border_labels))

    # Make the edge transition transparent without destroying white sleeves
    # or highlights that are enclosed by the foreground silhouette.
    alpha = np.where(background, 0.0, 1.0)
    band = ndimage.binary_dilation(background, iterations=4) & ~background
    alpha[band] = np.minimum(alpha[band], np.clip((255.0 - minimum[band]) / 70.0, 0.0, 1.0))
    alpha = ndimage.gaussian_filter(alpha, 0.7)
    rgb = image.copy()
    destination.parent.mkdir(parents=True, exist_ok=True)
    output = np.dstack([rgb.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    Image.fromarray(output, "RGBA").save(destination)
    return {
        "input": str(source),
        "output": str(destination),
        "width": int(image.shape[1]),
        "height": int(image.shape[0]),
        "border_components_removed": len(border_labels),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(remove_background(args.input, args.output))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
