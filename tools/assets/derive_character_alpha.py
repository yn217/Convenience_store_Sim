"""Derive transparent pilot standing sprites without removing disconnected white clothing."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "assets" / "runtime" / "character_pilot"
OUTPUT_DIR = SOURCE_DIR / "derived_alpha"
PILOT_FILES = (
    "event_neighbor_mentions.png",
    "fullbody_dynamic_201.png",
    "fullbody_emotion_05.png",
    "fullbody_tutorial_layout.png",
    "functional_opening_checklist.png",
    "functional_rival_store.png",
    "functional_sold_out.png",
)


def near_white(pixel: tuple[int, int, int, int], threshold: int = 42) -> bool:
    r, g, b, _ = pixel
    return min(r, g, b) >= 255 - threshold and max(r, g, b) - min(r, g, b) <= 18


def connected_background(image: Image.Image) -> set[tuple[int, int]]:
    width, height = image.size
    pixels = image.load()
    seen: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not near_white(pixels[x, y]):
            continue
        seen.add((x, y))
        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    return seen


def derive(source: Path, destination: Path) -> int:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    background = connected_background(image)
    for x, y in background:
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, "PNG", optimize=True)
    return len(background)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for filename in PILOT_FILES:
        source = SOURCE_DIR / filename
        destination = OUTPUT_DIR / filename
        cleared = derive(source, destination)
        print(f"{filename}: cleared_background_pixels={cleared}")


if __name__ == "__main__":
    main()
