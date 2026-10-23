"""Validate review-only fixture material candidates and their provenance paths."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/materials/MATERIAL_PROVENANCE.json"
MANIFEST = ROOT / "assets/source/textures/materials/MATERIAL_CANDIDATE_MANIFEST.json"

def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
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
    if len(manifest["entries"]) != variants - len(ids):
        problems.append("candidate manifest count mismatch")
    for entry in manifest["entries"]:
        if entry["selection_status"] != "review-only" or entry["runtime_approved"] is not False:
            problems.append(f"runtime status not conservative: {entry['visual_id']}")
        path = ROOT / entry["asset"]["path"]
        if not path.is_file():
            problems.append(f"manifest missing: {entry['asset']['path']}")
        elif __import__("hashlib").sha256(path.read_bytes()).hexdigest() != entry["asset"]["sha256"]:
            problems.append(f"manifest hash mismatch: {entry['asset']['path']}")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"MATERIAL CROSSWALK: PASS - {len(ids)} fixtures, {variants} source/variant paths, runtime not approved")

if __name__ == "__main__":
    main()
