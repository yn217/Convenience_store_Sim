"""Issue #167: the fixture / product masters validate against their JSON Schemas, and the check catches bad entries."""
import copy
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "validation"))
import check_schemas as cs  # noqa: E402

FIXTURES = json.loads((ROOT / "data/fixtures/mvp_v1.json").read_text(encoding="utf-8"))
PRODUCTS = json.loads((ROOT / "data/products/mvp_v1.json").read_text(encoding="utf-8"))
FIXTURE_SCHEMA = json.loads((ROOT / "docs/schemas/fixture_definition.schema.json").read_text(encoding="utf-8"))
PRODUCT_SCHEMA = json.loads((ROOT / "docs/schemas/product_definition.schema.json").read_text(encoding="utf-8"))


def fixture(type_id: str) -> dict:
    return copy.deepcopy(next(f for f in FIXTURES if f["type_id"] == type_id))


class Schemas(unittest.TestCase):
    def test_repo_passes(self):
        self.assertEqual(cs.main(ROOT), 0)
        self.assertEqual(len(FIXTURES), 28)
        self.assertEqual(len(PRODUCTS), 62)

    def test_every_category_in_use_is_allowed(self):
        cats = cs.runtime_categories(ROOT)
        self.assertEqual(len(cats), 20)
        self.assertTrue({p["category"] for p in PRODUCTS} <= set(cats))
        for enum in cs.category_enums(FIXTURE_SCHEMA) + cs.category_enums(PRODUCT_SCHEMA):
            self.assertEqual(enum, cats)

    def test_bad_fixtures_are_caught(self):
        f = fixture("shelf_goods")
        del f["visual_id"]
        self.assertTrue(any("missing required visual_id" in e for e in cs.validate(f, FIXTURE_SCHEMA)))
        f = fixture("shelf_goods")
        f["footprint"]["w"] = 0
        self.assertTrue(any("footprint.w" in e for e in cs.validate(f, FIXTURE_SCHEMA)))
        f = fixture("shelf_goods")
        f["shelf_slots"][0]["allowed_categories"] = ["medicine"]
        self.assertTrue(any("not one of the allowed values" in e for e in cs.validate(f, FIXTURE_SCHEMA)))
        f = fixture("shelf_goods")
        f["access_edges"] = ["S", "S"]
        self.assertTrue(any("not unique" in e for e in cs.validate(f, FIXTURE_SCHEMA)))
        f = fixture("shelf_goods")
        f["dimensions_m"]["height"] = 0
        self.assertTrue(any("exclusiveMinimum" in e for e in cs.validate(f, FIXTURE_SCHEMA)))
        f = fixture("staff_room_s")
        f["staff_capacity"] = "3"
        self.assertTrue(any("staff_capacity" in e for e in cs.validate(f, FIXTURE_SCHEMA)))
        f = fixture("shelf_goods")
        f["sale_bonus"] = 1
        self.assertTrue(any("unknown key sale_bonus" in e for e in cs.validate(f, FIXTURE_SCHEMA)))

    def test_bad_products_are_caught(self):
        p = copy.deepcopy(PRODUCTS[0])
        p["sku_id"] = "Onigiri-1"
        self.assertTrue(any("does not match" in e for e in cs.validate(p, PRODUCT_SCHEMA)))
        p = copy.deepcopy(PRODUCTS[0])
        p["default_sell_price_yen"] = 0
        self.assertTrue(any("minimum" in e for e in cs.validate(p, PRODUCT_SCHEMA)))
        p = copy.deepcopy(PRODUCTS[0])
        p["purchase_cost_yen"] = 12.5
        self.assertTrue(any("not of type integer" in e for e in cs.validate(p, PRODUCT_SCHEMA)))
        p = copy.deepcopy(PRODUCTS[0])
        p["demand_weight"] = True
        self.assertTrue(any("not of type number" in e for e in cs.validate(p, PRODUCT_SCHEMA)))
        p = copy.deepcopy(PRODUCTS[0])
        p["expires_after_seconds"] = None
        self.assertEqual(cs.validate(p, PRODUCT_SCHEMA), [], "null = never expires")

    def test_unknown_schema_keyword_is_an_error(self):
        errs = cs.validate("x", {"type": "string", "maxLength": 3})
        self.assertTrue(any("maxLength is not checked" in e for e in errs))

    def test_a_category_added_only_at_runtime_is_caught(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            for rel in ("data/fixtures/mvp_v1.json", "data/products/mvp_v1.json", "docs/schemas/fixture_definition.schema.json",
                        "docs/schemas/product_definition.schema.json", "scripts/domain/product_catalog.gd"):
                (tmp / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(ROOT / rel, tmp / rel)
            gd = tmp / "scripts/domain/product_catalog.gd"
            gd.write_text(gd.read_text(encoding="utf-8").replace('"crane_prize",', '"crane_prize", "medicine",', 1), encoding="utf-8")
            self.assertEqual(cs.main(tmp), 1)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
