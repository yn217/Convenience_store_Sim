"""Approve explicitly reviewed character-pilot registry rows.

This is intentionally opt-in.  A dry run is the default; changing the registry
requires ``--apply`` plus both visual-QA and rights-review confirmations.  The
334-image placement proposal is never modified here.
"""

from __future__ import annotations

import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "presentation" / "character_visuals_v1.json"


def _repo_path(value: str) -> Path:
    return ROOT / value.removeprefix("res://")


def load_registry(path: Path = REGISTRY) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def find_entries(document: dict, ids: list[str]) -> list[dict]:
    entries = document.get("assets")
    if not isinstance(entries, list):
        raise ValueError("registry has no assets array")
    by_id = {str(entry.get("id", "")): entry for entry in entries if isinstance(entry, dict)}
    missing = [asset_id for asset_id in ids if asset_id not in by_id]
    if missing:
        raise ValueError("unknown registry id(s): " + ", ".join(missing))
    return [by_id[asset_id] for asset_id in ids]


def validate_entry(entry: dict) -> list[str]:
    errors: list[str] = []
    asset_id = str(entry.get("id", "<unknown>"))
    runtime = str(entry.get("runtime_path", ""))
    if not runtime or not _repo_path(runtime).is_file():
        errors.append(f"{asset_id}: missing runtime_path")
    source = str(entry.get("source_path", ""))
    if source and not _repo_path(source).is_file():
        errors.append(f"{asset_id}: missing source_path")
    derived = str(entry.get("derived_from", ""))
    if derived and not _repo_path(derived).is_file():
        errors.append(f"{asset_id}: missing derived_from")
    if not entry.get("fallback"):
        errors.append(f"{asset_id}: fallback is required")
    return errors


def approve(path: Path, ids: list[str], *, apply: bool, visual_qa: bool, rights: bool) -> Path | None:
    if apply and not (visual_qa and rights):
        raise ValueError("--apply requires --visual-qa-confirmed and --rights-confirmed")
    document = load_registry(path)
    selected = find_entries(document, ids)
    errors = [error for entry in selected for error in validate_entry(entry)]
    if errors:
        raise ValueError("\n".join(errors))
    print("candidate(s): " + ", ".join(str(entry["id"]) for entry in selected))
    print("validation: OK")
    if not apply:
        print("dry-run: registry unchanged (use --apply with both confirmations to write)")
        return None

    backup = path.with_suffix(path.suffix + ".backup-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ"))
    backup.write_bytes(path.read_bytes())
    for entry in selected:
        entry["runtime_approved"] = True
        entry["status"] = "runtime_approved"
        entry["approval_recorded_at"] = datetime.now(timezone.utc).isoformat()
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temp, path)
    print(f"approved: {len(selected)}")
    try:
        backup_label = str(backup.relative_to(ROOT))
    except ValueError:
        backup_label = str(backup)
    print(f"backup: {backup_label}")
    return backup


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ids", nargs="+", help="registry ids, for example functional_low_stock")
    parser.add_argument("--apply", action="store_true", help="write approvals; without this the command is a dry run")
    parser.add_argument("--visual-qa-confirmed", action="store_true")
    parser.add_argument("--rights-confirmed", action="store_true")
    parser.add_argument("--registry", type=Path, default=REGISTRY, help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        approve(args.registry, args.ids, apply=args.apply, visual_qa=args.visual_qa_confirmed, rights=args.rights_confirmed)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        parser.error(str(exc))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
