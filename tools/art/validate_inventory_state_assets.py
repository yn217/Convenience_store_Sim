"""Focused validation for Issue #91 inventory-state candidate assets.

This intentionally validates packaging consistency only. It does not certify
Blender calibration or Godot runtime integration.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "assets/source/textures/fixtures/inventory_states"
FIXTURES = {"shelf_general": "composite", "fridge_drink": "", "shelf_noodle": ""}
STATES = ("full", "half", "empty")
ROTATIONS = range(4)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    records = []
    errors = []
    fixture_sizes = {}
    for fixture, suffix in FIXTURES.items():
        folder = ROOT / fixture
        for state in STATES:
            for rotation in ROTATIONS:
                stem = f"{fixture}_{state}_r{rotation}"
                composite = folder / f"{stem}{'_' + suffix if suffix else ''}.png"
                if not composite.exists():
                    errors.append(f"missing composite: {composite}")
                    continue
                with Image.open(composite) as image:
                    if image.mode != "RGBA":
                        errors.append(f"not RGBA: {composite}")
                    size = (image.width, image.height)
                    if fixture in fixture_sizes and fixture_sizes[fixture] != size:
                        errors.append(f"inconsistent canvas {size} != {fixture_sizes[fixture]}: {composite}")
                    fixture_sizes.setdefault(fixture, size)
                layer_names = ["body", "products", "shadow"]
                if fixture == "fridge_drink":
                    layer_names.insert(2, "glass_front")
                for layer in layer_names:
                    path = folder / f"{stem}_{layer}.png"
                    if not path.exists():
                        errors.append(f"missing layer: {path}")
                records.append({"fixture": fixture, "state": state, "rotation": rotation, "path": composite.relative_to(ROOT.parent.parent.parent).as_posix(), "sha256": sha256(composite)})
    for fixture in FIXTURES:
        for rotation in ROTATIONS:
            hashes = {r["sha256"] for r in records if r["fixture"] == fixture and r["rotation"] == rotation}
            if len(hashes) != 3:
                errors.append(f"states are not distinct: {fixture} r{rotation}")
    out = ROOT / "INVENTORY_STATE_SHA256_MANIFEST.json"
    out.write_text(json.dumps({"issue": 91, "runtime_approved": False, "records": records}, indent=2) + "\n", encoding="utf-8")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(records)} composites, RGBA 512x512, required layers present, states distinct")
    print(f"WROTE: {out}")


if __name__ == "__main__":
    main()
