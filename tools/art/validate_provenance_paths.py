"""Validate asset paths recorded in provenance JSON files."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "assets"

def walk(value):
    if isinstance(value, dict):
        for item in value.values():
            yield from walk(item)
    elif isinstance(value, list):
        for item in value:
            yield from walk(item)
    elif isinstance(value, str) and value.startswith("assets/"):
        yield value

def main() -> None:
    problems = []
    checked = 0
    for path in sorted(ASSET_ROOT.rglob("*PROVENANCE.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        for recorded in walk(data):
            checked += 1
            target = ROOT / recorded
            if not target.is_file():
                problems.append(f"{path.relative_to(ROOT)} -> missing {recorded}")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"PROVENANCE PATHS: PASS - {checked} asset paths across provenance files")

if __name__ == "__main__":
    main()
