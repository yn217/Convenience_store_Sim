"""Audit of docs/ASSET_CREDITS.md against assets/generated (Issue #29).

Fails when a generated asset directory has no ledger row, a row points at a missing path, a row has an
unknown/empty licence, an unknown source type or redistribution is not 'yes', or an AI / third-party row
lacks a model/source. Usage: python check_asset_credits.py <repo root>
"""
import sys
from pathlib import Path

SOURCE_TYPES = {"Blender", "AI", "third-party", "code"}
BAD = {"", "—", "-", "unknown", "不明", "未確認", "tbd"}


def parse(root: Path):
    rows = []
    for line in (root / "docs/ASSET_CREDITS.md").read_text(encoding="utf-8").splitlines():
        if not line.startswith("|") or line.startswith("|---") or line.startswith("|asset_id"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 9:
            rows.append(dict(zip(["asset_id", "path", "source_type", "source", "model", "license", "date", "review", "redistribution"], cells)))
    return rows


def problems(root: Path):
    out = []
    rows = parse(root)
    if not rows:
        out.append("no rows in the ledger")
    ids = set()
    for r in rows:
        if r["asset_id"] in ids:
            out.append(f"{r['asset_id']}: duplicate asset_id")
        ids.add(r["asset_id"])
        if r["source_type"] not in SOURCE_TYPES:
            out.append(f"{r['asset_id']}: unknown source_type {r['source_type']!r}")
        if not (root / r["path"]).exists():
            out.append(f"{r['asset_id']}: path missing: {r['path']}")
        if r["license"].lower() in BAD:
            out.append(f"{r['asset_id']}: licence unknown")
        if r["redistribution"].lower() != "yes":
            out.append(f"{r['asset_id']}: redistribution is not 'yes'")
        if r["source"].lower() in BAD or r["model"].lower() in BAD:
            out.append(f"{r['asset_id']}: source / model missing")
        if r["source_type"] in ("AI", "third-party") and ("prompt" not in r["source"].lower() and "http" not in r["source"].lower()):
            out.append(f"{r['asset_id']}: AI / third-party rows need the prompt or a source link")
    covered = {r["path"].rstrip("/") for r in rows}
    gen = root / "assets/generated"
    for group in sorted(p for p in gen.iterdir() if p.is_dir()):
        for d in sorted(p for p in group.iterdir() if p.is_dir()):
            rel = d.relative_to(root).as_posix()
            if rel not in covered:
                out.append(f"{rel}: generated asset without a ledger row")
    return out


def main(root: Path) -> int:
    errs = problems(root)
    for e in errs:
        print("CREDITS:", e)
    print(f"asset credits check: {len(errs)} problem(s)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()))
