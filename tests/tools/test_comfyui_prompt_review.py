"""Focused checks for the read-only ComfyUI prompt review report."""

import csv
import json
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "tools" / "assets" / "report_comfyui_prompt_review.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("comfyui_prompt_review", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ComfyUiPromptReview(unittest.TestCase):
    def test_report_reads_all_candidates_without_approving_them(self):
        module = _load_module()
        with module.CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        report = module.build_report(rows)

        self.assertEqual(report["summary"]["candidate_count"], 334)
        self.assertEqual(report["summary"]["metadata_readable"], 334)
        self.assertEqual(report["summary"]["metadata_complete"], 334)
        self.assertEqual(report["summary"]["seed_matches_csv"], 61)
        self.assertEqual(report["summary"]["filename_prefix_matches_png"], 334)
        self.assertEqual(report["summary"]["image_size_matches_group"], 334)
        # The report intentionally exposes the existing CSV/PNG seed mismatch;
        # it must not silently rewrite the human-editable placement table.
        self.assertEqual(report["summary"]["alignment_ok"], 61)
        self.assertEqual(report["summary"]["visual_match_verified"], 0)
        self.assertEqual(report["summary"]["runtime_approved"], 0)
        self.assertTrue(all(asset["visual_match"] == "not_yet_verified" for asset in report["assets"]))
        self.assertTrue(all(asset["runtime_approved"] is False for asset in report["assets"]))

    def test_workflow_metadata_extracts_positive_negative_and_seed(self):
        module = _load_module()
        with module.CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
            row = next(csv.DictReader(handle))
        source = module.CANDIDATE_ROOT / row["candidate_relpath"]
        from PIL import Image

        with Image.open(source) as image:
            metadata = module._workflow_metadata(image)
        self.assertIn("koharu_rikka", metadata["positive"])
        self.assertIn("worst quality", metadata["negative"])
        self.assertIn(int(row["seed"]), metadata["seeds"])


if __name__ == "__main__":
    unittest.main()
