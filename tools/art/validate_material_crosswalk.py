"""Validate review-only fixture material candidates and their provenance paths."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/materials/MATERIAL_PROVENANCE.json"

def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    problems = []
    ids = []
    variants = 0
    for fixture in data["fixtures"]:
        fixture_id = fixture["fixture_type_id"]
        ids.append(fixture_id)
        if len(fixture["variants"]) != 2:
            problems.append(f"expected two variants: {fixture_id}")
        for path in [fixture["source_board"], *fixture["variants"]]:
            if not (ROOT / path).is_file():
                problems.append(f"missing: {path}")
            else:
                variants += 1
    if len(ids) != len(set(ids)):
        problems.append("duplicate fixture_type_id")
    if data.get("status", "").find("not runtime") < 0:
        problems.append("runtime-only status is not explicit")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"MATERIAL CROSSWALK: PASS - {len(ids)} fixtures, {variants} source/variant paths, runtime not approved")

if __name__ == "__main__":
    main()
