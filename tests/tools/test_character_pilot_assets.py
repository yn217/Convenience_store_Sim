"""Focused integrity checks for the selected character-pilot PNGs."""

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "presentation" / "character_visuals_v1.json"


class CharacterPilotAssetTests(unittest.TestCase):
    def test_display_derivation_keeps_the_original_fullbody_canvas(self):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        derived = [
            entry for entry in registry["assets"]
            if "/derived_alpha/" in entry.get("runtime_path", "")
        ]

        for entry in derived:
            runtime_path = ROOT / entry["runtime_path"].removeprefix("res://")
            source_ref = entry.get("derived_from", "")
            source_path = ROOT / source_ref.removeprefix("res://")
            self.assertTrue(runtime_path.is_file(), entry["id"])
            self.assertTrue(source_path.is_file(), entry["id"])
            self.assertNotEqual(runtime_path.resolve(), source_path.resolve(), entry["id"])
            with Image.open(source_path) as original:
                expected_size = (1024, 1024) if entry.get("kind") == "bustup_reaction" else (1024, 1536)
                self.assertEqual(original.size, expected_size, entry["id"])

    def test_derived_pilot_images_keep_canvas_and_transparent_corners(self):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        derived = [
            entry for entry in registry["assets"]
            if "/derived_alpha/" in entry.get("runtime_path", "")
        ]
        self.assertEqual(len(derived), 49)

        for entry in derived:
            runtime_path = ROOT / entry["runtime_path"].removeprefix("res://")
            self.assertTrue(runtime_path.is_file(), entry["id"])
            with Image.open(runtime_path) as image:
                rgba = image.convert("RGBA")
                expected_size = (1024, 1024) if entry.get("kind") == "bustup_reaction" else (1024, 1536)
                self.assertEqual(rgba.size, expected_size, entry["id"])
                alpha = rgba.getchannel("A")
                self.assertIsNotNone(alpha.getbbox(), entry["id"])
                corners = [
                    alpha.getpixel((0, 0)),
                    alpha.getpixel((rgba.width - 1, 0)),
                    alpha.getpixel((0, rgba.height - 1)),
                    alpha.getpixel((rgba.width - 1, rgba.height - 1)),
                ]
                self.assertEqual(corners, [0, 0, 0, 0], entry["id"])


if __name__ == "__main__":
    unittest.main()
