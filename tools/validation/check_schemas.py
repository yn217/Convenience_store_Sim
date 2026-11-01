"""Validates the runtime masters against their JSON Schemas (#167): every fixture of data/fixtures/mvp_v1.json against
docs/schemas/fixture_definition.schema.json, every SKU of data/products/mvp_v1.json against
product_definition.schema.json, and the schemas' category enums against ProductCatalog.CATEGORIES.

The validator covers the Draft 2020-12 keywords these schemas use (type, const, enum, required, properties,
additionalProperties, items, minItems, uniqueItems, minLength, pattern, minimum, exclusiveMinimum); any other
keyword in a schema is an error, so a schema can not silently ask for a check that is not made.
Usage: python check_schemas.py <repo root>
"""
import json
import re
import sys
from pathlib import Path

KNOWN = {"$schema", "$id", "title", "description", "type", "const", "enum", "required", "properties",
         "additionalProperties", "items", "minItems", "uniqueItems", "minLength", "pattern", "minimum", "exclusiveMinimum"}
TYPES = {
    "object": lambda v: isinstance(v, dict),
    "array": lambda v: isinstance(v, list),
    "string": lambda v: isinstance(v, str),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "boolean": lambda v: isinstance(v, bool),
    "null": lambda v: v is None,
}
PAIRS = [("data/fixtures/mvp_v1.json", "fixtures", "docs/schemas/fixture_definition.schema.json", "type_id"),
         ("data/products/mvp_v1.json", "skus", "docs/schemas/product_definition.schema.json", "sku_id")]


def validate(value, schema: dict, path: str = "$") -> list:
    """Error messages for `value` against `schema` (empty when valid)."""
    errs = ["%s: schema keyword %s is not checked by this validator" % (path, k) for k in schema if k not in KNOWN]
    if "type" in schema:
        types = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(TYPES[t](value) for t in types):
            return errs + ["%s: %r is not of type %s" % (path, value, "/".join(types))]
    if "const" in schema and value != schema["const"]:
        errs.append("%s: %r != %r" % (path, value, schema["const"]))
    if "enum" in schema and value not in schema["enum"]:
        errs.append("%s: %r is not one of the allowed values" % (path, value))
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errs.append("%s: %r < minimum %r" % (path, value, schema["minimum"]))
        if "exclusiveMinimum" in schema and value <= schema["exclusiveMinimum"]:
            errs.append("%s: %r <= exclusiveMinimum %r" % (path, value, schema["exclusiveMinimum"]))
    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errs.append("%s: shorter than %d" % (path, schema["minLength"]))
        if "pattern" in schema and not re.search(schema["pattern"], value):
            errs.append("%s: %r does not match %s" % (path, value, schema["pattern"]))
    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errs.append("%s: fewer than %d items" % (path, schema["minItems"]))
        if schema.get("uniqueItems") and len({json.dumps(v, sort_keys=True) for v in value}) != len(value):
            errs.append("%s: items are not unique" % path)
        if "items" in schema:
            for i, v in enumerate(value):
                errs += validate(v, schema["items"], "%s[%d]" % (path, i))
    if isinstance(value, dict):
        props = schema.get("properties", {})
        for k in schema.get("required", []):
            if k not in value:
                errs.append("%s: missing required %s" % (path, k))
        for k, v in value.items():
            if k in props:
                errs += validate(v, props[k], "%s.%s" % (path, k))
            elif schema.get("additionalProperties") is False:
                errs.append("%s: unknown key %s" % (path, k))
    return errs


def category_enums(schema) -> list:
    """Every enum list under an allowed_categories or category key."""
    out = []
    if isinstance(schema, dict):
        for k, v in schema.items():
            if k in ("category", "allowed_categories") and isinstance(v, dict):
                out.append((v.get("items", v)).get("enum"))
            out += category_enums(v)
    elif isinstance(schema, list):
        for v in schema:
            out += category_enums(v)
    return out


def runtime_categories(root: Path) -> list:
    src = (root / "scripts/domain/product_catalog.gd").read_text(encoding="utf-8")
    m = re.search(r"const CATEGORIES[^=]*=\s*\[(.*?)\]", src, re.S)
    return re.findall(r'"([a-z_]+)"', m.group(1)) if m else []


def main(root: Path) -> int:
    errs = []
    cats = runtime_categories(root)
    if not cats:
        errs.append("ProductCatalog.CATEGORIES not found")
    for data_path, key, schema_path, id_key in PAIRS:
        schema = json.loads((root / schema_path).read_text(encoding="utf-8"))
        for enum in category_enums(schema):
            if enum != cats:
                errs.append("%s: category enum differs from ProductCatalog.CATEGORIES" % schema_path)
        doc = json.loads((root / data_path).read_text(encoding="utf-8"))
        items = doc[key] if isinstance(doc, dict) else doc
        for i, item in enumerate(items):
            name = "%s %s" % (data_path, item.get(id_key, "#%d" % i) if isinstance(item, dict) else "#%d" % i)
            errs += ["%s: %s" % (name, e) for e in validate(item, schema)]
    for e in errs:
        print("SCHEMA: " + e)
    print("schema check: %d problem(s)" % len(errs))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()))
