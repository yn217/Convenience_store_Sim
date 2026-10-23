"""Validate the generated-asset provenance ledger and referenced files."""

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CREDITS = ROOT / "docs" / "ASSET_CREDITS.md"


def _repo_path(value: str) -> Path:
    value = value.strip().strip("`")
    return ROOT / value.replace("/**", "")


def _rows():
    for line in CREDITS.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|") or line.startswith("|asset_id|") or line.startswith("|---"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) == 9:
            yield cells


def main() -> int:
    problems = []
    if not CREDITS.is_file():
        print("provenance check: missing docs/ASSET_CREDITS.md")
        return 1
    rows = list(_rows())
    if not rows:
        problems.append("credits ledger has no asset rows")
    for asset_id, asset_path, _source_type, source_refs, _model, _terms, _date, _review, _redistribution in rows:
        asset_root = _repo_path(asset_path)
        if not asset_root.exists():
            problems.append(f"{asset_id}: asset path missing: {asset_path}")
        for ref in re.findall(r"(?:assets|tools|data|docs)/[^; ,]+", source_refs):
            if not _repo_path(ref).exists():
                problems.append(f"{asset_id}: provenance reference missing: {ref}")
    for provenance in (
        ROOT / "assets/generated/fixtures/PROVENANCE.json",
        ROOT / "assets/generated/characters/PROVENANCE.json",
        ROOT / "assets/generated/products/PROVENANCE.json",
    ):
        if not provenance.is_file():
            problems.append(f"missing provenance manifest: {provenance.relative_to(ROOT)}")
            continue
        try:
            json.loads(provenance.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            problems.append(f"invalid provenance JSON: {provenance.relative_to(ROOT)} ({exc})")
    print(f"provenance check: {len(rows)} ledger rows, {len(problems)} problem(s)")
    for problem in problems:
        print(f"- {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
