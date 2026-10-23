"""Join existing visual IDs with review-only package source and LOD paths."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_MAP = ROOT / "assets/source/textures/packages/CANDIDATE_VISUAL_ID_MAP.json"
OUT = ROOT / "assets/source/textures/packages/candidates/lod/VISUAL_LOD_MANIFEST.json"

def main() -> None:
    source = json.loads(SOURCE_MAP.read_text(encoding="utf-8"))
    entries = []
    for category in source["candidates"]:
        for index, (visual_id, source_path) in enumerate(zip(category["existing_visual_ids"], category["source_variants"]), 1):
            stem = Path(source_path).stem
            entries.append({
                "category": category["category"],
                "existing_visual_id": visual_id,
                "candidate_variant": f"{category['category']}_{index:03d}",
                "selected": False,
                "source_cutout": source_path,
                "lod_0_5": f"assets/source/textures/packages/candidates/lod/{stem}_lod_0_5.png",
                "lod_0_25": f"assets/source/textures/packages/candidates/lod/{stem}_lod_0_25.png",
                "status": "review-only; fallback to existing procedural visual_id"
            })
    OUT.write_text(json.dumps({"status": "review-only; does not replace runtime manifest", "entries": entries}, indent=2) + "\n", encoding="utf-8")
    print(f"mapped {len(entries)} visual IDs -> {OUT.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
