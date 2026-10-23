"""Focused validation for package LOD outputs."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets/source/textures/packages/candidates/lod/LOD_MANIFEST.json"

def main() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    problems = []
    for item in data["outputs"]:
        path = ROOT / item["path"]
        if not path.is_file():
            problems.append(f"missing: {item['path']}")
            continue
        with Image.open(path) as image:
            if image.mode != "RGBA":
                problems.append(f"not RGBA: {item['path']}")
            if list(image.size) != item["dimensions"]:
                problems.append(f"size mismatch: {item['path']}")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"PACKAGE LODS: PASS - {len(data['outputs'])} files")

if __name__ == "__main__":
    main()
