"""Record provisional customer cutout bounds without asserting a game anchor."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROV = ROOT / "assets/source/textures/characters/CUSTOMER_PROVENANCE.json"
OUT = ROOT / "assets/source/textures/characters/CUSTOMER_STAGING_MANIFEST.json"
CHAR_ROOT = PROV.parent

def main() -> None:
    data = json.loads(PROV.read_text(encoding="utf-8"))
    entries = []
    for index, item in enumerate(data["cutouts"], 1):
        path = ROOT / item["path"] if item["path"].startswith("assets/") else CHAR_ROOT / item["path"]
        with Image.open(path).convert("RGBA") as image:
            alpha = image.getchannel("A")
            bbox = alpha.getbbox()
            bottom_rows = [y for y in range(image.height) if alpha.crop((0, y, image.width, y + 1)).getbbox()]
            bottom = max(bottom_rows) if bottom_rows else None
            entry = {
                "variant_id": f"customer_{index:03d}",
                "source": item["path"],
                "normalized_source": f"assets/source/textures/characters/candidates/source_1024/{Path(item['path']).name.replace('_v01.png', '_source1024_v01.png')}",
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "canvas_px": [image.width, image.height],
                "alpha_bbox": list(bbox) if bbox else None,
                "provisional_bottom_alpha_row": bottom,
                "projection_id": None,
                "anchor_px": None,
                "sorting_anchor_px": None,
                "runtime_approved": False,
                "selection_status": "needs_human_review"
            }
            normalized = ROOT / entry["normalized_source"]
            if normalized.is_file():
                entry["normalized_sha256"] = hashlib.sha256(normalized.read_bytes()).hexdigest()
                entry["normalized_dimensions"] = [1024, 1536]
            cleaned = CHAR_ROOT / "candidates/source_1024/customer_casual_tote_cutout_cleaned_v01.png"
            if index == 1 and cleaned.is_file():
                entry["derived_candidates"] = [{"path": "candidates/source_1024/customer_casual_tote_cutout_cleaned_v01.png", "sha256": hashlib.sha256(cleaned.read_bytes()).hexdigest(), "method": "tools/art/clean_customer_alpha_candidate.py", "input": item["path"], "runtime_approved": False, "selection_status": "needs_human_review"}]
            entries.append(entry)
    OUT.write_text(json.dumps({"status": "source-art staging only; no iso2x or world anchor asserted", "entries": entries}, indent=2) + "\n", encoding="utf-8")
    print(f"customer staging manifest: {len(entries)} candidates")

if __name__ == "__main__":
    main()
