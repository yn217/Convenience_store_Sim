"""Focused integrity checks for the selected character-pilot PNGs."""

import json
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "presentation" / "character_visuals_v1.json"
PLACEMENT = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.json"
REVIEW_DERIVED = ROOT / "assets" / "review" / "derived_alpha"
CANDIDATE_ROOT = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui"


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

    def test_review_alpha_derivations_trace_to_334_mapping(self):
        """Review-only cutouts must remain traceable without becoming runtime assets."""
        placement = json.loads(PLACEMENT.read_text(encoding="utf-8"))
        entries = {entry["asset_id"]: entry for entry in placement["assets"]}
        derived = sorted(REVIEW_DERIVED.glob("*.png"))
        self.assertGreater(len(derived), 0)

        for output in derived:
            asset_id = output.stem
            self.assertIn(asset_id, entries, asset_id)
            entry = entries[asset_id]
            source = CANDIDATE_ROOT / entry["candidate_relpath"]
            self.assertTrue(source.is_file(), asset_id)
            self.assertFalse(bool(entry.get("runtime_approved", False)), asset_id)
            with Image.open(source) as original, Image.open(output) as cutout:
                self.assertEqual(cutout.mode, "RGBA", asset_id)
                self.assertEqual(cutout.size, original.size, asset_id)
                alpha = cutout.getchannel("A")
                self.assertIsNotNone(alpha.getbbox(), asset_id)
                corners = [
                    alpha.getpixel((0, 0)),
                    alpha.getpixel((cutout.width - 1, 0)),
                    alpha.getpixel((0, cutout.height - 1)),
                    alpha.getpixel((cutout.width - 1, cutout.height - 1)),
                ]
                self.assertEqual(corners, [0, 0, 0, 0], asset_id)


if __name__ == "__main__":
    unittest.main()
