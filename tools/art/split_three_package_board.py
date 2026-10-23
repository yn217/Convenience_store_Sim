"""Split the three-panel review-only package board into lossless staging crops."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/packages/oden_bread_snack_comparison_v01.png"
OUT = ROOT / "assets/source/textures/packages/candidates"
NAMES = ("oden", "bread", "snack")

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    records = []
    with Image.open(SOURCE) as image:
        image = image.convert("RGBA")
        w, h = image.size
        # Preserve generous visual margins while excluding neighboring products.
        boxes = ((0, 0, w // 3 - 10, h), (w // 3 + 10, 0, 2 * w // 3 - 10, h), (2 * w // 3 + 10, 0, w, h))
        for name, box in zip(NAMES, boxes):
            path = OUT / f"{name}_comparison_candidate_v01.png"
            image.crop(box).save(path, format="PNG", optimize=False)
            records.append({"family": name, "source": str(SOURCE.relative_to(ROOT)), "file": str(path.relative_to(ROOT)), "crop_box": list(box), "size": [box[2] - box[0], box[3] - box[1]], "selection_status": "review-only", "runtime_approved": False})
    manifest = OUT / "oden_bread_snack_candidates.json"
    manifest.write_text(json.dumps({"method": "Pillow lossless RGBA crop", "source": str(SOURCE.relative_to(ROOT)), "candidates": records}, indent=2) + "\n", encoding="utf-8")
    print(f"split {len(records)} package candidates")

if __name__ == "__main__":
    main()
