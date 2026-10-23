"""Record SHA-256 hashes for generated/source art review artifacts."""
from hashlib import sha256
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GROUPS = {
    "packages": ROOT / "assets/source/textures/packages",
    "fixtures": ROOT / "assets/source/textures/fixtures",
    "materials": ROOT / "assets/source/textures/materials",
    "pop": ROOT / "assets/source/textures/pop",
    "characters": ROOT / "assets/source/textures/characters",
}
OUT = ROOT / "assets/source/textures/ASSET_SHA256_MANIFEST.json"

def main() -> None:
    files = []
    for group, directory in GROUPS.items():
        for path in sorted(directory.rglob("*")):
            if path.is_file() and path.suffix.lower() in {".png", ".json", ".md"}:
                digest = sha256(path.read_bytes()).hexdigest()
                files.append({"group": group, "path": path.relative_to(ROOT).as_posix(), "sha256": digest, "bytes": path.stat().st_size})
    OUT.write_text(json.dumps({"algorithm": "SHA-256", "files": files}, indent=2) + "\n", encoding="utf-8")
    print(f"hashed {len(files)} files -> {OUT.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
