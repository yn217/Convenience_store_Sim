"""Focused integrity check for the Issue #230 334-image placement table."""

import csv
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.csv"
JSON_PATH = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.json"
CANDIDATE_ROOT = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui"


class ComfyUiPlacementIntegrity(unittest.TestCase):
    def test_csv_json_and_candidate_files_stay_aligned(self):
        with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
            csv_rows = list(csv.DictReader(handle))
        with JSON_PATH.open(encoding="utf-8") as handle:
            document = json.load(handle)

        self.assertEqual(len(csv_rows), 334)
        self.assertEqual(document["candidate_count"], 334)
        self.assertEqual(len(document["assets"]), 334)
        self.assertFalse(document["runtime_approved"])
        self.assertEqual(
            [row["asset_id"] for row in csv_rows],
            [row["asset_id"] for row in document["assets"]],
        )
        self.assertEqual(len({row["asset_id"] for row in csv_rows}), 334)
        self.assertTrue(all((CANDIDATE_ROOT / row["candidate_relpath"]).is_file() for row in csv_rows))


if __name__ == "__main__":
    unittest.main()
