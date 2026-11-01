"""Export the 334-image placement table as a typed, review-only JSON manifest.

The CSV remains the human-editable source. This exporter intentionally preserves
the proposed/verified/approval fields instead of turning a placement proposal
into runtime approval.
"""

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.csv"
OUTPUT_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.json"


def export() -> None:
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 334:
        raise ValueError(f"expected 334 placement rows, got {len(rows)}")

    asset_ids = [row["asset_id"] for row in rows]
    if len(set(asset_ids)) != len(asset_ids):
        raise ValueError("placement table contains duplicate asset_id values")

    typed_rows = []
    for row in rows:
        typed = dict(row)
        typed["seed"] = int(row["seed"])
        typed_rows.append(typed)

    document = {
        "schema_version": 1,
        "status": "placement_proposal",
        "runtime_approved": False,
        "source_csv": CSV_PATH.relative_to(ROOT).as_posix(),
        "source_manifest": "assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/generation_manifest.json",
        "candidate_count": len(typed_rows),
        "runtime_approved_count": 0,
        "notes": [
            "This table assigns proposed screens and triggers; it does not approve images for runtime use.",
            "visual_match remains not_yet_verified until image and embedded prompt review is complete.",
            "The CSV is the human-editable source; regenerate this JSON after CSV changes.",
        ],
        "assets": typed_rows,
    }
    OUTPUT_PATH.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    export()
    print(f"wrote {OUTPUT_PATH} ({334} rows)")
