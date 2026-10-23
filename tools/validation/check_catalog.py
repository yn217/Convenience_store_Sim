"""Fails when the runtime masters under data/ drift from the reviewed docs/examples copies.

docs/examples/README.md: the arrays are copied (never hand-retyped) into res://data/.
Usage: python check_catalog.py <repo root>
"""
import json
import sys
from pathlib import Path

PAIRS = [
    ("docs/examples/mvp_v1.fixtures.json", "data/fixtures/mvp_v1.json"),
    ("docs/examples/mvp_v1.products.json", "data/products/mvp_v1.json"),
    ("docs/examples/mvp_v1.balance.json", "data/balance/mvp_v1.json"),
    ("docs/examples/mvp_v1.milestones.json", "data/progression/mvp_v1.milestones.json"),
    ("docs/examples/empty_store.savegame.json", "tests/data/empty_store.savegame.json"),
]


def main(root: Path) -> int:
    bad = 0
    for src, dst in PAIRS:
        a = json.loads((root / src).read_text(encoding="utf-8"))
        b = json.loads((root / dst).read_text(encoding="utf-8"))
        if a != b:
            print(f"CATALOG: {dst} differs from {src}")
            bad += 1
    print(f"catalog sync check: {bad} mismatch(es)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()))
