"""Focused static gate for the fictional shelf POP source staging tree."""
from pathlib import Path
import json
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
POP = ROOT / "assets/source/textures/pop"


def main() -> int:
    errors = []
    provenance = json.loads((POP / "POP_PROVENANCE.json").read_text(encoding="utf-8"))
    for relative in [provenance["source_file"], *provenance["source_candidates"], *provenance["cutout_outputs"]]:
        if not (ROOT / relative).exists():
            errors.append(f"missing provenance path: {relative}")
    cutouts = sorted((POP / "candidates").glob("*_cutout_v02.png"))
    canvases = sorted((POP / "candidates/source_256").glob("*_source256_v01.png"))
    if len(cutouts) != 2:
        errors.append(f"expected 2 normalized POP cutouts, got {len(cutouts)}")
    if len(canvases) != 2:
        errors.append(f"expected 2 POP source canvases, got {len(canvases)}")
    for path in cutouts:
        with Image.open(path) as image:
            alpha = image.getchannel("A") if image.mode == "RGBA" else None
            bbox = alpha.getbbox() if alpha else None
            if image.mode != "RGBA" or bbox is None or bbox[3] != image.height or bbox[0] == 0 or bbox[2] == image.width:
                errors.append(f"{path.name}: invalid RGBA/alpha contact or padding {image.mode} {bbox}")
    for path in canvases:
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != (256, 256):
                errors.append(f"{path.name}: expected RGBA 256x256, got {image.mode} {image.size}")
    if errors:
        print("POP STAGING: FAIL")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("POP STAGING: PASS - 2 cutouts, 2 RGBA 256x256 canvases, provenance paths present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
