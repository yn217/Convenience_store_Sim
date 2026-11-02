"""Remove known generated comic-symbol regions from selected reaction derivatives.

The ComfyUI source and the pre-cleaned source copy are never changed.  This is
an explicit, reviewable mask for the three pilot reactions whose generated
speech bubbles are not part of the character art; Godot owns the final symbol
overlay.  Keep the rectangles narrow so hair, buns, shoulders, and hands are
not affected.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


REGIONS: dict[str, tuple[int, int, int, int]] = {
    "reaction_discovery.png": (760, 0, 1024, 240),
    "reaction_deadpan.png": (740, 0, 1024, 220),
    "reaction_pleading.png": (800, 0, 1024, 340),
}


def clean(source: Path, destination: Path) -> dict[str, str | tuple[int, int, int, int]]:
    image = Image.open(source).convert("RGBA")
    rgba = np.array(image)
    region = REGIONS.get(source.name)
    if region is None:
        raise ValueError(f"no explicit symbol region for {source.name}")
    left, top, right, bottom = region
    rgba[top:bottom, left:right, 3] = 0
    rgba[top:bottom, left:right, :3] = 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(destination)
    return {"input": str(source), "output": str(destination), "region": region}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", nargs="+", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--in-place", action="store_true")
    args = parser.parse_args()
    if args.in_place == bool(args.output_dir):
        parser.error("use exactly one of --in-place or --output-dir")
    for source in args.input:
        destination = source if args.in_place else args.output_dir / source.name
        print(clean(source, destination))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
