"""Validate the six baseline fixture material source candidates."""
from pathlib import Path
import json
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    data = json.loads((ROOT / "assets/source/textures/materials/MATERIAL_PROVENANCE.json").read_text(encoding="utf-8"))
    errors = []
    variants = []
    for fixture in data["fixtures"]:
        if len(fixture["variants"]) != 2:
            errors.append(f"{fixture['fixture_type_id']}: expected 2 variants")
        for relative in [fixture["source_board"], *fixture["variants"]]:
            path = ROOT / relative
            if not path.exists():
                errors.append(f"missing: {relative}")
            elif relative in fixture["variants"]:
                variants.append(path)
    for path in variants:
        with Image.open(path) as image:
            if image.mode not in {"RGB", "RGBA"}:
                errors.append(f"{path.name}: unexpected mode {image.mode}")
            if image.width < 256 or image.height < 256:
                errors.append(f"{path.name}: too small {image.size}")
    if errors:
        print("MATERIAL CANDIDATES: FAIL")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MATERIAL CANDIDATES: PASS - 3 fixtures, 6 variants, provenance paths present")
    return 0


if __name__ == "__main__":
    sys.exit(main())
