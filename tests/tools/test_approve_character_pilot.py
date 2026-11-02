"""Tests for the explicit, dry-run-by-default pilot approval tool."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.assets.approve_character_pilot import approve


ROOT = Path(__file__).resolve().parents[2]


class CharacterPilotApprovalTests(unittest.TestCase):
    def _copy_registry(self, directory: Path) -> Path:
        path = directory / "registry.json"
        path.write_text((ROOT / "data/presentation/character_visuals_v1.json").read_text(encoding="utf-8"), encoding="utf-8")
        return path

    def test_dry_run_does_not_change_registry(self):
        with tempfile.TemporaryDirectory() as temp:
            path = self._copy_registry(Path(temp))
            before = path.read_bytes()
            with patch("tools.assets.approve_character_pilot.REGISTRY", path):
                approve(path, ["functional_low_stock"], apply=False, visual_qa=False, rights=False)
            self.assertEqual(path.read_bytes(), before)

    def test_apply_requires_both_confirmations(self):
        with tempfile.TemporaryDirectory() as temp:
            path = self._copy_registry(Path(temp))
            with self.assertRaises(ValueError):
                approve(path, ["functional_low_stock"], apply=True, visual_qa=True, rights=False)

    def test_apply_is_individual_and_creates_backup(self):
        with tempfile.TemporaryDirectory() as temp:
            path = self._copy_registry(Path(temp))
            backup = approve(path, ["functional_low_stock"], apply=True, visual_qa=True, rights=True)
            self.assertIsNotNone(backup)
            self.assertTrue(backup.is_file())
            document = json.loads(path.read_text(encoding="utf-8"))
            rows = {row["id"]: row for row in document["assets"]}
            self.assertTrue(rows["functional_low_stock"]["runtime_approved"])
            self.assertEqual(rows["functional_low_stock"]["status"], "runtime_approved")
            self.assertFalse(rows["functional_queue"]["runtime_approved"])


if __name__ == "__main__":
    unittest.main()
