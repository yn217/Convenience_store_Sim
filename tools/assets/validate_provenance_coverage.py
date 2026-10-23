"""Cross-check generated asset IDs against the provenance coverage index.

This complements ``validate_provenance.py``: path/reference validation can pass
while a newly added fixture or SKU is absent from the human-readable ledger.
"""
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CREDITS = ROOT / "docs" / "ASSET_CREDITS.md"
FIXTURE_CATALOG = ROOT / "data" / "fixtures" / "mvp_v1.json"
PRODUCT_CATALOG = ROOT / "data" / "products" / "mvp_v1.json"
PRODUCT_MANIFEST = ROOT / "assets" / "generated" / "products" / "products_manifest.json"


def fixture_ids():
    catalog = json.loads(FIXTURE_CATALOG.read_text(encoding="utf-8"))
    if isinstance(catalog, list):
        return {entry["type_id"] for entry in catalog}
    return set(catalog)


def product_ids():
    catalog = json.loads(PRODUCT_CATALOG.read_text(encoding="utf-8"))
    catalog_ids = {entry["visual_id"] for entry in catalog}
    manifest = json.loads(PRODUCT_MANIFEST.read_text(encoding="utf-8"))
    manifest_ids = set(manifest["products"])
    return catalog_ids, manifest_ids


def main():
    text = CREDITS.read_text(encoding="utf-8")
    fixtures = fixture_ids()
    catalog_products, manifest_products = product_ids()
    problems = []
    if catalog_products != manifest_products:
        problems.append("product catalog/manifest mismatch: catalog-only=%s manifest-only=%s" % (
            sorted(catalog_products - manifest_products), sorted(manifest_products - catalog_products)))
    missing_fixtures = sorted(asset_id for asset_id in fixtures if asset_id not in text)
    missing_products = sorted(asset_id for asset_id in catalog_products if asset_id not in text)
    if missing_fixtures:
        problems.append("fixture IDs absent from ASSET_CREDITS coverage index: %s" % ", ".join(missing_fixtures))
    if missing_products:
        problems.append("product visual IDs absent from ASSET_CREDITS coverage index: %s" % ", ".join(missing_products))
    print("provenance coverage: %d fixtures, %d product visual IDs, %d problem(s)" % (
        len(fixtures), len(catalog_products), len(problems)))
    for problem in problems:
        print("- " + problem)
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
