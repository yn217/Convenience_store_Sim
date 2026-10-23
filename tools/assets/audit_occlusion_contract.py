"""Audit fixture manifests for runtime occlusion layer readiness.

This check does not infer depth from a single opaque body PNG.  It reports whether
each rotation exposes explicit back/front fixture layers required to compose
products and customers around the fixture (Issue #26).

    python tools/assets/audit_occlusion_contract.py
    python tools/assets/audit_occlusion_contract.py --require-split

The default mode is informational and exits 0.  ``--require-split`` is the
adoption gate and exits 1 while any fixture rotation lacks both explicit body
split layers.  This keeps the current asset pipeline honest without blocking
ordinary manifest validation.
"""
import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DIR = ROOT / "assets" / "generated" / "fixtures"
SPLIT_KEYS = {"fixture_back", "fixture_front"}


def audit(directory):
    rows = []
    for path in sorted(directory.glob("*/*.visual.json")):
        manifest = json.loads(path.read_text(encoding="utf-8"))
        rotations = manifest.get("rotations", {})
        for rotation in ("0", "1", "2", "3"):
            layers = set(rotations.get(rotation, {}).get("layers", {}))
            split = bool(layers & SPLIT_KEYS)
            rows.append({
                "fixture_type_id": manifest.get("fixture_type_id", path.parent.name),
                "rotation": int(rotation),
                "layers": sorted(layers),
                "explicit_body_split": split,
            })
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", type=Path, default=DEFAULT_DIR)
    parser.add_argument("--require-split", action="store_true")
    args = parser.parse_args()
    rows = audit(args.dir)
    missing = [row for row in rows if not row["explicit_body_split"]]
    for row in rows:
        status = "PASS" if row["explicit_body_split"] else "PENDING"
        print("%s %s r%d layers=%s" % (
            status, row["fixture_type_id"], row["rotation"], ",".join(row["layers"])))
    print("occlusion check: %d rotations, %d with explicit body split, %d pending" % (
        len(rows), len(rows) - len(missing), len(missing)))
    if args.require_split and missing:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
