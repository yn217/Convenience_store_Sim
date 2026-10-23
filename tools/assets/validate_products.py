"""Validate reusable product shape sprites and the SKU mapping manifest."""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PRODUCTS = ROOT / "assets" / "generated" / "products"
CATALOG = ROOT / "data" / "products" / "mvp_v1.json"
EXPECTED_SHAPES = {"onigiri_triangle", "oden_piece", "cup_noodle", "bread_bag", "bottle_500", "snack_pouch", "dessert_cup", "ice_bar_pack"}


def main() -> int:
    errors = []
    dirs = {p.name for p in PRODUCTS.iterdir() if p.is_dir()} if PRODUCTS.exists() else set()
    if dirs != EXPECTED_SHAPES:
        errors.append(f"shape directories differ: {sorted(dirs)}")
    for shape in sorted(EXPECTED_SHAPES & dirs):
        manifest_path = PRODUCTS / shape / f"{shape}.product.json"
        if not manifest_path.exists():
            errors.append(f"{shape}: missing manifest")
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("projection_id") != "iso2x_v1":
            errors.append(f"{shape}: wrong projection")
        directions = manifest.get("directions", {})
        if set(directions) != {"0", "1", "2", "3"}:
            errors.append(f"{shape}: directions must be 0..3")
        for rel in directions.values():
            path = PRODUCTS / shape / rel
            if not path.exists():
                errors.append(f"{shape}: missing {rel}")
                continue
            with Image.open(path) as image:
                if image.mode != "RGBA":
                    errors.append(f"{shape}/{rel}: not RGBA")
                if image.size != (256, 256):
                    errors.append(f"{shape}/{rel}: unexpected canvas {image.size}")
    mapping_path = PRODUCTS / "products_manifest.json"
    if not mapping_path.exists():
        errors.append("missing products_manifest.json")
    else:
        mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        expected = {p["visual_id"] for p in catalog}
        actual = set(mapping.get("products", {}))
        if actual != expected:
            errors.append(f"SKU visual IDs differ: expected {len(expected)}, got {len(actual)}")
        for visual_id, spec in mapping.get("products", {}).items():
            if spec.get("shape_id") not in EXPECTED_SHAPES:
                errors.append(f"{visual_id}: unknown shape")
            if set(spec.get("directions", {})) != {"0", "1", "2", "3"}:
                errors.append(f"{visual_id}: incomplete direction mapping")
            for rel in spec.get("directions", {}).values():
                if not (PRODUCTS / rel).exists():
                    errors.append(f"{visual_id}: missing {rel}")
    if errors:
        print("PRODUCTS:")
        print("\n".join(f"- {e}" for e in errors))
        return 1
    print(f"product check: {len(EXPECTED_SHAPES)} shapes, 4 directions each, {len(json.loads(CATALOG.read_text(encoding='utf-8')))} SKU mappings, 0 problems")
    return 0


if __name__ == "__main__":
    sys.exit(main())
