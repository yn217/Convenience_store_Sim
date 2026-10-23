"""Single focused gate for the generated package source-art staging tree."""
from pathlib import Path
import json
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    errors = []
    provenance = load(ROOT / "assets/source/textures/CANDIDATE_PROVENANCE.json")
    cutout = load(ROOT / "assets/source/textures/packages/CUTOUT_PROVENANCE.json")
    mapping = load(ROOT / "assets/source/textures/packages/CANDIDATE_VISUAL_ID_MAP.json")
    examples = load(ROOT / "docs/examples/mvp_v1.products.json")
    known_ids = {item["visual_id"] for item in examples}

    paths = [item["file"] for item in provenance["candidates"]]
    paths += cutout["source_boards"] + cutout["source_candidates"]
    paths += [item["file"] for item in cutout["outputs"]]
    for relative in paths:
        if not (ROOT / relative).exists():
            errors.append(f"missing provenance path: {relative}")

    for candidate in mapping["candidates"]:
        for visual_id in candidate["existing_visual_ids"]:
            if visual_id not in known_ids:
                errors.append(f"unknown visual_id: {visual_id}")

    v02 = sorted((ROOT / "assets/source/textures/packages/candidates").glob("*_cutout_v02.png"))
    source256 = sorted((ROOT / "assets/source/textures/packages/candidates/source_256").glob("*_source256_v01.png"))
    if len(v02) != 6:
        errors.append(f"expected 6 normalized cutouts, got {len(v02)}")
    if len(source256) != 6:
        errors.append(f"expected 6 source canvases, got {len(source256)}")
    for path in v02:
        with Image.open(path) as image:
            if image.mode != "RGBA":
                errors.append(f"{path.name}: not RGBA")
            alpha = image.getchannel("A")
            bbox = alpha.getbbox()
            if bbox is None or bbox[3] != image.height or bbox[0] == 0 or bbox[2] == image.width:
                errors.append(f"{path.name}: invalid alpha contact/padding {bbox}")
    for path in source256:
        with Image.open(path) as image:
            if image.mode != "RGBA" or image.size != (256, 256):
                errors.append(f"{path.name}: expected RGBA 256x256, got {image.mode} {image.size}")

    if errors:
        print("PACKAGE STAGING: FAIL")
        print("\n".join(f"- {item}" for item in errors))
        return 1
    print("PACKAGE STAGING: PASS - 21 provenance paths, 6 normalized cutouts, 6 RGBA 256x256 source canvases, 6 existing visual IDs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
