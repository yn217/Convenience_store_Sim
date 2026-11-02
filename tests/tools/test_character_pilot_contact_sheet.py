"""Focused checks for the read-only pilot contact-sheet filters."""

import unittest

from tools.assets.build_character_pilot_contact_sheet import _load_entries


class CharacterPilotContactSheetTests(unittest.TestCase):
    def test_core_and_unapproved_filters_partition_the_registry(self):
        core = _load_entries(core_only=True)
        remaining = _load_entries(unapproved_only=True)
        self.assertEqual(len(core), 11)
        self.assertEqual(len(remaining), 39)
        self.assertTrue(all(bool(entry.get("runtime_approved")) for entry in core))
        self.assertTrue(all(not bool(entry.get("runtime_approved")) for entry in remaining))
        self.assertEqual(
            {entry["id"] for entry in core} | {entry["id"] for entry in remaining},
            {entry["id"] for entry in _load_entries()},
        )
        self.assertFalse(
            {entry["id"] for entry in core} & {entry["id"] for entry in remaining}
        )


if __name__ == "__main__":
    unittest.main()
