"""Focused integrity checks for the selected character-pilot PNGs."""

import json
import csv
from pathlib import Path
import unittest

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "data" / "presentation" / "character_visuals_v1.json"
PLACEMENT = ROOT / "docs" / "art" / "COMFYUI_334_IMAGE_PLACEMENT_20261101.json"
CORE_QA = ROOT / "docs" / "art" / "CHARACTER_VISUAL_CORE_QA_20261103.csv"
REVIEW_DERIVED = ROOT / "assets" / "review" / "derived_alpha"
CANDIDATE_ROOT = ROOT / "assets" / "review" / "imagegen_candidates" / "20261031" / "issue30_31_32_comfyui"
REACTION_SYMBOL_REGIONS = {
    "reaction_discovery": (760, 0, 1024, 240),
    "reaction_deadpan": (740, 0, 1024, 220),
    "reaction_pleading": (800, 0, 1024, 340),
    "reaction_first_sale_joy": (820, 320, 1024, 630),
}


class CharacterPilotAssetTests(unittest.TestCase):
    def test_core_qa_table_matches_registry_and_keeps_open_review_gates(self):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        expected = set(registry["core_pilot_ids"])
        with CORE_QA.open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(len(rows), 11)
        self.assertEqual({row["asset_id"] for row in rows}, expected)
        required = {
            "asset_id", "screen_id", "kind", "visual_match", "alpha_check",
            "layout_capture", "hand_review", "rights_review", "approval_state",
        }
        for row in rows:
            self.assertTrue(required.issubset(row), row["asset_id"])
            self.assertEqual(row["approval_state"], "review_only", row["asset_id"])
            self.assertEqual(row["hand_review"], "pending_detail", row["asset_id"])
            self.assertEqual(row["rights_review"], "pending", row["asset_id"])

    def test_pilot_routes_use_deferred_loads_instead_of_preloading_the_registry(self):
        """The 50 candidate textures must not become a startup preload/cache."""
        scripts = [
            ROOT / "scripts" / "presentation" / "character_visual_pilot_panel.gd",
            ROOT / "scripts" / "presentation" / "progression_controller.gd",
            ROOT / "scripts" / "presentation" / "event_controller.gd",
            ROOT / "scripts" / "presentation" / "title_screen.gd",
        ]
        for path in scripts:
            source = path.read_text(encoding="utf-8")
            self.assertNotIn("preload(\"res://assets/runtime/character_pilot/", source, path.name)
        progression = (ROOT / "scripts" / "presentation" / "progression_controller.gd").read_text(encoding="utf-8")
        events = (ROOT / "scripts" / "presentation" / "event_controller.gd").read_text(encoding="utf-8")
        self.assertIn("load(String(entry.get(\"runtime_path\", \"\")))", progression)
        self.assertIn("load(String(pilot_entry.get(\"runtime_path\", \"\")))", events)

    def test_core_pilot_has_the_issue_230_minimum_11_routes(self):
        """The initial visual QA set is explicit without reducing the 50-entry registry."""
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        assets = {entry["id"]: entry for entry in registry["assets"]}
        core = registry.get("core_pilot_ids", [])
        self.assertEqual(len(core), 11)
        self.assertEqual(len(set(core)), 11)
        self.assertTrue(set(core).issubset(assets))
        self.assertEqual(len(assets), 50)
        self.assertEqual(assets["title_background_pilot"]["kind"], "title_background")
        self.assertEqual(
            [assets[asset_id]["kind"] for asset_id in core].count("bustup_reaction"),
            3,
        )
        self.assertEqual(
            [assets[asset_id]["kind"] for asset_id in core].count("event_image"),
            1,
        )
        self.assertTrue(all(not bool(assets[asset_id].get("runtime_approved", False)) for asset_id in core))
        for asset_id in core:
            runtime_path = str(assets[asset_id].get("runtime_path", ""))
            self.assertTrue(runtime_path.startswith("res://"), asset_id)
            self.assertTrue((ROOT / runtime_path.removeprefix("res://")).is_file(), asset_id)

    def test_runtime_registry_entries_trace_to_the_334_placement_rows(self):
        """Every pilot route must point at the same source candidate recorded in the placement table."""
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        placement = json.loads(PLACEMENT.read_text(encoding="utf-8"))
        placement_by_source = {
            str(entry["candidate_relpath"]): entry
            for entry in placement["assets"]
        }
        registry_entries = [
            entry for entry in registry["assets"]
            if entry.get("source_path", "").startswith("assets/review/imagegen_candidates/")
        ]
        self.assertGreaterEqual(len(registry_entries), 49)

        for entry in registry_entries:
            source_ref = str(entry["source_path"])
            source_path = ROOT / source_ref
            self.assertTrue(source_path.is_file(), entry["id"])
            # The title pilot is intentionally maintained in the separate title
            # candidate set; it is not one of the 329 character rows in the
            # 334-image placement table.
            if not source_ref.startswith(
                "assets/review/imagegen_candidates/20261031/issue30_31_32_comfyui/"
            ):
                self.assertEqual(entry.get("kind"), "title_background", entry["id"])
                runtime_ref = str(entry.get("runtime_path", ""))
                self.assertTrue((ROOT / runtime_ref.removeprefix("res://")).is_file(), entry["id"])
                continue
            candidate_relpath = source_ref.split("issue30_31_32_comfyui/", 1)[-1]
            mapped = placement_by_source.get(candidate_relpath)
            self.assertIsNotNone(mapped, entry["id"])
            self.assertTrue(mapped["asset_id"].strip(), entry["id"])
            self.assertFalse(bool(mapped.get("runtime_approved", False)), entry["id"])

            runtime_ref = str(entry.get("runtime_path", ""))
            if runtime_ref.startswith("res://"):
                self.assertTrue((ROOT / runtime_ref.removeprefix("res://")).is_file(), entry["id"])

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

    def test_fullbody_derivatives_do_not_drop_interior_colored_pixels(self):
        """A background cutout must not erase a solid interior part of the uniform or body."""
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        for entry in registry["assets"]:
            if entry.get("kind") == "bustup_reaction" or "/derived_alpha/" not in entry.get("runtime_path", ""):
                continue
            source_path = ROOT / entry["derived_from"].removeprefix("res://")
            runtime_path = ROOT / entry["runtime_path"].removeprefix("res://")
            with Image.open(source_path) as source_image, Image.open(runtime_path) as runtime_image:
                source = np.asarray(source_image.convert("RGB"))
                alpha = np.asarray(runtime_image.convert("RGBA"))[:, :, 3]
            # White background is excluded, and a 2px erosion ignores only the
            # expected anti-aliased silhouette edge. Interior colored pixels
            # becoming transparent are the failure mode seen in broken cutouts.
            colored = (source.min(axis=2) < 225) | ((source.max(axis=2) - source.min(axis=2)) > 22)
            interior = cv2.erode(colored.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
            lost = int(np.count_nonzero(interior & (alpha < 16)))
            self.assertLessEqual(lost, 64, f"{entry['id']}: {lost} interior source pixels became transparent")

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

    def test_all_reaction_review_candidates_have_derived_alpha(self):
        """Every reaction candidate has a review cutout, while approval stays separate."""
        placement = json.loads(PLACEMENT.read_text(encoding="utf-8"))
        reactions = [
            entry for entry in placement["assets"]
            if "reaction" in entry.get("group", "")
        ]
        self.assertEqual(len(reactions), 50)

        for entry in reactions:
            asset_id = entry["asset_id"]
            output = REVIEW_DERIVED / f"{asset_id}.png"
            self.assertTrue(output.is_file(), asset_id)
            self.assertFalse(bool(entry.get("runtime_approved", False)), asset_id)
            with Image.open(output) as image:
                self.assertEqual(image.mode, "RGBA", asset_id)
                self.assertEqual(image.size, (1024, 1024), asset_id)
                self.assertIsNotNone(image.getchannel("A").getbbox(), asset_id)

    def test_review_alpha_scope_keeps_title_backgrounds_opaque(self):
        """Review alpha derivatives cover character candidates, never title backgrounds."""
        placement = json.loads(PLACEMENT.read_text(encoding="utf-8"))
        title_rows = [
            entry for entry in placement["assets"]
            if "title" in entry.get("group", "")
        ]
        character_rows = [
            entry for entry in placement["assets"]
            if "title" not in entry.get("group", "")
        ]
        self.assertEqual(len(title_rows), 5)
        self.assertEqual(len(character_rows), 329)
        self.assertEqual(len(list(REVIEW_DERIVED.glob("*.png"))), len(character_rows))
        for entry in title_rows:
            self.assertFalse((REVIEW_DERIVED / f"{entry['asset_id']}.png").exists(), entry["asset_id"])
        for entry in character_rows:
            self.assertTrue((REVIEW_DERIVED / f"{entry['asset_id']}.png").is_file(), entry["asset_id"])

    def test_clean_reactions_do_not_keep_small_disconnected_symbols(self):
        for asset_id in ("reaction_discovery", "reaction_deadpan", "reaction_pleading"):
            path = ROOT / "assets" / "runtime" / "character_pilot" / "derived_alpha" / f"{asset_id}.png"
            with Image.open(path) as image:
                alpha = np.array(image.convert("RGBA").getchannel("A"))
            count, _labels, stats, _centroids = cv2.connectedComponentsWithStats(
                (alpha > 32).astype(np.uint8), connectivity=8
            )
            self.assertGreaterEqual(count, 2, asset_id)
            areas = stats[1:, cv2.CC_STAT_AREA]
            largest = int(areas.max())
            self.assertTrue(np.all(areas >= largest * 0.05), asset_id)

    def test_clean_reactions_clear_known_generated_symbol_regions(self):
        """The explicit symbol masks clear only the selected derived PNGs."""
        for asset_id, (left, top, right, bottom) in REACTION_SYMBOL_REGIONS.items():
            runtime = ROOT / "assets" / "runtime" / "character_pilot" / "derived_alpha" / f"{asset_id}.png"
            source = ROOT / "assets" / "runtime" / "character_pilot" / f"{asset_id}.png"
            self.assertTrue(runtime.is_file(), asset_id)
            self.assertTrue(source.is_file(), asset_id)
            with Image.open(runtime) as image:
                alpha = np.array(image.convert("RGBA"))[:, :, 3]
            self.assertEqual(int(alpha[top:bottom, left:right].max()), 0, asset_id)

    def test_first_sale_reaction_keeps_canvas_and_has_transparent_corners(self):
        path = ROOT / "assets" / "runtime" / "character_pilot" / "derived_alpha" / "reaction_first_sale_joy.png"
        with Image.open(path) as image:
            rgba = image.convert("RGBA")
            self.assertEqual(rgba.size, (1024, 1024))
            alpha = np.array(rgba.getchannel("A"))
        self.assertEqual([int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])], [0, 0, 0, 0])


if __name__ == "__main__":
    unittest.main()
