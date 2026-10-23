"""Build explicit per-variant material candidate metadata for Issue #22."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/materials/MATERIAL_PROVENANCE.json"
OUT = ROOT / "assets/source/textures/materials/MATERIAL_CANDIDATE_MANIFEST.json"

def record(path: str) -> dict:
    target = ROOT / path
    return {"path": path, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "bytes": target.stat().st_size}

def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    entries = []
    for fixture in data["fixtures"]:
        fixture_id = fixture["fixture_type_id"]
        for index, variant in enumerate(fixture["variants"], 1):
            variant_id = chr(96 + index)
            entries.append({
                "fixture_type_id": fixture_id,
                "visual_id": f"{fixture_id}_{variant_id}",
                "variant_id": variant_id,
                "selection_status": "review-only",
                "runtime_approved": False,
                "asset": record(variant),
            })
    OUT.write_text(json.dumps({"status": "candidate-only; not runtime-approved", "scope": "three baseline fixture material families", "entries": entries}, indent=2) + "\n", encoding="utf-8")
    print(f"material manifest: {len(entries)} variants -> {OUT.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
