"""Report review-only package candidate coverage against the product catalog."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRODUCTS = ROOT / "docs/examples/mvp_v1.products.json"
VISUAL = ROOT / "assets/source/textures/packages/candidates/lod/VISUAL_LOD_MANIFEST.json"
OUT = ROOT / "assets/source/textures/packages/PACKAGE_VISUAL_COVERAGE.json"

def main() -> None:
    products = json.loads(PRODUCTS.read_text(encoding="utf-8"))
    visual = json.loads(VISUAL.read_text(encoding="utf-8"))
    mapped = {entry["existing_visual_id"]: entry for entry in visual["entries"]}
    rows = []
    for product in products:
        visual_id = product["visual_id"]
        entry = mapped.get(visual_id)
        rows.append({"sku_id": product["sku_id"], "category": product["category"], "visual_id": visual_id, "candidate_status": "review-only" if entry else "not_registered", "candidate_variant": entry.get("candidate_variant") if entry else None, "runtime_approved": False})
    OUT.write_text(json.dumps({"status": "coverage report only; existing procedural runtime remains fallback", "total_products": len(rows), "review_only_products": sum(row["candidate_status"] == "review-only" for row in rows), "rows": rows}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"package coverage: {sum(row['candidate_status'] == 'review-only' for row in rows)}/{len(rows)} have review candidates")

if __name__ == "__main__":
    main()
