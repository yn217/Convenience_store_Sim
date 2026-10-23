"""Create a conservative crosswalk report for Issue #29 asset provenance."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/art/ASSET_CROSSWALK_AUDIT.json"

def paths(value):
    if isinstance(value, dict):
        for item in value.values(): yield from paths(item)
    elif isinstance(value, list):
        for item in value: yield from paths(item)
    elif isinstance(value, str) and value.startswith("assets/"):
        yield value

def main() -> None:
    provenance = []
    for path in sorted((ROOT / "assets").rglob("*PROVENANCE.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        refs = sorted(set(paths(data)))
        provenance.append({"file": path.relative_to(ROOT).as_posix(), "asset_paths": refs, "missing_paths": [p for p in refs if not (ROOT / p).is_file()], "status": data.get("status", "unspecified")})
    products = json.loads((ROOT / "docs/examples/mvp_v1.products.json").read_text(encoding="utf-8"))
    visual = json.loads((ROOT / "assets/source/textures/packages/candidates/lod/VISUAL_LOD_MANIFEST.json").read_text(encoding="utf-8"))
    mapped = {entry["existing_visual_id"] for entry in visual["entries"]}
    product_ids = {item["visual_id"] for item in products}
    report = {
        "scope": "Issue #29 source-art provenance crosswalk",
        "runtime_policy": "review-only candidates must not replace procedural runtime assets",
        "provenance_files": provenance,
        "product_visual_ids": {"total": len(product_ids), "mapped_review_only": len(mapped & product_ids), "unmapped": sorted(product_ids - mapped)},
        "review_only_visual_ids": sorted(mapped),
        "unapproved_status": "present where provenance says pending/review-only; not treated as complete",
    }
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    missing = sum(len(item["missing_paths"]) for item in provenance)
    print(f"ASSET CROSSWALK: {len(provenance)} provenance files, {len(product_ids)} product visual IDs, {len(mapped & product_ids)} review mappings, missing paths={missing}")

if __name__ == "__main__":
    main()
