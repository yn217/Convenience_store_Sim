"""Check fixture layer visibility and anchor scaling at representative zooms.

This raster-level check covers all generated fixtures and four rotations.  It does
not replace Godot camera, selection, or runtime depth acceptance.
"""
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "assets" / "generated" / "fixtures"
ZOOMS = (0.5, 1.0, 2.0)


def main():
    problems = []
    checks = 0
    for path in sorted(FIXTURES.glob("*/*.visual.json")):
        manifest = json.loads(path.read_text(encoding="utf-8"))
        for rotation, rot in sorted(manifest["rotations"].items(), key=lambda item: int(item[0])):
            canvas = tuple(rot["canvas_px"])
            anchor = tuple(rot["anchor_px"])
            for zoom in ZOOMS:
                checks += 1
                target = tuple(max(1, int(round(value * zoom))) for value in canvas)
                scaled_anchor = tuple(value * zoom for value in anchor)
                if any(value < 0 or value > target[index] for index, value in enumerate(scaled_anchor)):
                    problems.append("%s r%s zoom%.1f: anchor outside scaled canvas" % (
                        manifest["fixture_type_id"], rotation, zoom))
                for layer, rel in rot["layers"].items():
                    image_path = path.parent / rel
                    with Image.open(image_path) as image:
                        if image.mode != "RGBA":
                            problems.append("%s r%s zoom%.1f: %s is not RGBA" % (
                                manifest["fixture_type_id"], rotation, zoom, layer))
                        resized = image.resize(target, Image.Resampling.LANCZOS)
                        if resized.getchannel("A").getbbox() is None:
                            problems.append("%s r%s zoom%.1f: %s became empty" % (
                                manifest["fixture_type_id"], rotation, zoom, layer))
    print("fixture zoom check: %d rotation/zoom checks, %d problem(s)" % (checks, len(problems)))
    for problem in problems:
        print("- " + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
