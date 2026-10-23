"""Verify every file listed in ASSET_SHA256_MANIFEST.json is unchanged."""
from hashlib import sha256
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "assets/source/textures/ASSET_SHA256_MANIFEST.json"

def main() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    problems = []
    for item in data["files"]:
        path = ROOT / item["path"]
        if not path.is_file():
            problems.append(f"missing: {item['path']}")
            continue
        digest = sha256(path.read_bytes()).hexdigest()
        if digest != item["sha256"]:
            problems.append(f"hash mismatch: {item['path']}")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"ASSET HASHES: PASS - {len(data['files'])} files")

if __name__ == "__main__":
    main()
