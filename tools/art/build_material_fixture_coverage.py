"""Report material candidate coverage against the authoritative fixture catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "docs/examples/mvp_v1.fixtures.json"
MATERIAL = ROOT / "assets/source/textures/materials/MATERIAL_CANDIDATE_MANIFEST.json"
OUT = ROOT / "assets/source/textures/materials/MATERIAL_FIXTURE_COVERAGE.json"

def main() -> None:
    fixtures = json.loads(FIXTURES.read_text(encoding="utf-8"))
    material = json.loads(MATERIAL.read_text(encoding="utf-8"))
    covered = {}
    for entry in material["entries"]:
        covered.setdefault(entry["fixture_type_id"], []).append(entry["visual_id"])
    rows = []
    for fixture in fixtures:
        fixture_id = fixture.get("fixture_type_id", fixture.get("type_id"))
        rows.append({"fixture_type_id": fixture_id, "catalog_visual_id": fixture.get("visual_id"), "candidate_visual_ids": covered.get(fixture_id, []), "candidate_status": "review-only" if fixture_id in covered else "not_registered", "runtime_approved": False})
    OUT.write_text(json.dumps({"status": "coverage report only; no runtime adoption", "total_catalog_fixtures": len(rows), "covered_baseline_fixtures": sum(bool(row["candidate_visual_ids"]) for row in rows), "rows": rows}, indent=2) + "\n", encoding="utf-8")
    print(f"fixture coverage: {sum(bool(row['candidate_visual_ids']) for row in rows)}/{len(rows)} have review candidates")

if __name__ == "__main__":
    main()
