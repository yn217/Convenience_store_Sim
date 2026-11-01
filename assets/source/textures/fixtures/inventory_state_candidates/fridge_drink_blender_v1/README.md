# Issue #91: calibrated Blender drink-cooler state candidate

This is a review candidate for `fridge_drink`, generated from the repository fixture blueprint and the shared `iso2x_v1` scene. It contains FULL/HALF/EMPTY × rotations 0–3, each with one depth-correct composite and body/products/glass-front/shadow reference passes.

- FULL: 24 modeled 500ml bottles (8 on each of 3 shelves).
- HALF: 12 bottles (4 on each shelf), not an opacity change.
- EMPTY: no products.
- Catalog fixture dimensions: 0.92 × 1.92 × 2.00m; 1 × 2 footprint.
- `manifest.json` has a common anchor/crop per rotation across all stock states.
- `contact_sheet.png` shows state and rotation coverage; `before_after_full_r0.png` compares the old placeholder-like Pillow candidate against this Blender render.
- `validation_report.json` contains measured projection, dimensions, image, and stock-count checks.

## Reproduce

From the repository root, using Blender 2.91 and Python with Pillow/NumPy:

```powershell
blender -b --python tools/assets/render_inventory_fixture_states.py -- --fixture fridge_drink --out build/fridge_drink_blender_v1
python tools/assets/build_inventory_fixture_states.py --raw build/fridge_drink_blender_v1 --out assets/source/textures/fixtures/inventory_state_candidates/fridge_drink_blender_v1
python tools/assets/validate_inventory_fixture_states.py assets/source/textures/fixtures/inventory_state_candidates/fridge_drink_blender_v1 --report assets/source/textures/fixtures/inventory_state_candidates/fridge_drink_blender_v1/validation_report.json
```

## Status and limitations

`runtime_approved` is deliberately `false`. This is not yet tested in Godot, across the required zoom levels, with the game's sorting/selection, or in the actual renderer. Back-facing rotations show the modeled rear of the cooler and therefore no products. The separate layers are reference passes; only the composite preserves per-pixel Blender depth occlusion. Small package label details become subtle at game-scale reduction, so visual acceptance remains open. No runtime/UI/Scene/Renderer/Domain files were changed.
