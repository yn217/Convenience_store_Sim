# Issue #91 inventory-state asset candidates

This package contains calibrated, asset-only Blender candidates for the first three inventory fixtures: `shelf_general`, `fridge_drink`, and `shelf_noodle`. The 3×3 comparison preview is `issue91_fixture_comparison_v01.png`; each fixture directory contains a 4-rotation contact sheet, FULL before/after comparison, calibration chart, manifest, provenance, and validation report.

## Candidate coverage

| Fixture | Blueprint dimensions | Product counts FULL/HALF/EMPTY |
| --- | --- | --- |
| `shelf_general` | 0.92 × 1.92 × 1.50 m | 32 / 16 / 0 |
| `fridge_drink` | 0.92 × 1.92 × 2.00 m | 24 / 12 / 0 |
| `shelf_noodle` | 0.92 × 1.92 × 1.70 m | 64 / 32 / 0 |

All fixtures use `iso2x_v1`, the repository blueprints, matching state/rotation crop and anchor records, transparent PNG outputs, and one common 3D source per fixture. FULL/HALF/EMPTY are visual merchandising states; game inventory remains integer-valued. The Blender composites are the depth-correct single images. `body`, `products`, `glass_front`, and `shadow` are reference passes; simply stacking those passes is not equivalent to per-pixel depth compositing.

## Reproduction

From the repository root, with Blender 2.91 and Python dependencies Pillow and NumPy installed. These commands render and validate one fixture; repeat the three stages for each fixture ID above. The candidate output directory can be selected independently.

```powershell
$fixture = "shelf_general"
$raw = "build/issue91_$fixture"
$out = "assets/source/textures/fixtures/inventory_state_candidates/${fixture}_blender_v1"
blender -b --python tools/assets/render_inventory_fixture_states.py -- --fixture $fixture --out $raw
python tools/assets/build_inventory_fixture_states.py --raw $raw --out $out
python tools/assets/validate_inventory_fixture_states.py $out --report "$out/validation_report.json"
```

After all three fixture candidates have been built, regenerate the shared comparison preview:

```powershell
python tools/assets/build_issue91_fixture_comparison.py
```

The renderer references the fictional package-art candidates under `assets/source/textures/packages/candidates/issue91_*_v01/`. Their prompts and generation/provenance notes are stored alongside each image. They are original generated candidates with no intentional real-world brands; licensing terms still require project-owner review before commercial release.

## Validation and approval boundary

Focused local validation passed for all three fixtures: projection calibration, all 12 state/rotation combinations, product-count ordering, measured mesh bounds, RGBA layer/crop consistency, and shared anchors/crops. See each `validation_report.json` for recorded checks. Python syntax compilation and `git diff --check` also pass.

These are review candidates, **not runtime-approved assets**. They have not been integrated into Godot, inspected at game zoom levels, tested with selection/sorting or neighboring characters/fixtures, or approved for commercial licensing. No Godot Scene, UI, Renderer, GameState, Domain, camera, or input code is changed here. The cooler's product colors are intentionally muted behind the glass in this render and need an in-game readability review. Keep `runtime_approved: false` until those checks are completed.
