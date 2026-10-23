"""Cross-check review-only package LOD mappings against source files and products."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
VISUAL = ROOT / "assets/source/textures/packages/candidates/lod/VISUAL_LOD_MANIFEST.json"
LOD = ROOT / "assets/source/textures/packages/candidates/lod/LOD_MANIFEST.json"
PRODUCTS = ROOT / "docs/examples/mvp_v1.products.json"

def main() -> None:
    visual = json.loads(VISUAL.read_text(encoding="utf-8"))
    lod = json.loads(LOD.read_text(encoding="utf-8"))
    products = json.loads(PRODUCTS.read_text(encoding="utf-8"))
    problems = []
    ids = [entry["existing_visual_id"] for entry in visual["entries"]]
    product_ids = {item["visual_id"] for item in products["products"]}
    if len(ids) != len(set(ids)):
        problems.append("duplicate visual_id")
    for entry in visual["entries"]:
        if entry.get("selected") is not False:
            problems.append(f"candidate marked selected: {entry['existing_visual_id']}")
        for key in ("source_cutout", "lod_0_5", "lod_0_25"):
            if not (ROOT / entry[key]).is_file():
                problems.append(f"missing {key}: {entry[key]}")
        if entry["existing_visual_id"] not in product_ids:
            problems.append(f"unknown visual_id: {entry['existing_visual_id']}")
    lod_by_path = {item["path"]: item for item in lod["outputs"]}
    for entry in visual["entries"]:
        for key in ("lod_0_5", "lod_0_25"):
            item = lod_by_path.get(entry[key])
            if item is None:
                problems.append(f"not in LOD manifest: {entry[key]}")
                continue
            source = ROOT / item["source"]
            with Image.open(source) as image:
                expected = [max(1, round(image.width * item["scale"])), max(1, round(image.height * item["scale"]))]
            if item["dimensions"] != expected:
                problems.append(f"dimension mismatch: {item['path']}")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"PACKAGE VISUAL LOD: PASS - {len(ids)} review mappings, {len(lod_by_path)} LODs")

if __name__ == "__main__":
    main()
