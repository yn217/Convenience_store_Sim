# Issue #91 inventory-state candidates

These are authoring/review candidates, not production-approved sprites. All manifests retain `runtime_approved: false`.

## Blender candidates

- `shelf_general_blender_v2/`: general rack, FULL/HALF/EMPTY × four 3D rotations, separate body/products/shadow and composite PNG layers.
- `shelf_noodle_blender_v1/`: cup-noodle rack, same state/rotation/layer contract.
- `fridge_drink_pillow_v2/`: exploratory Pillow concept copied from the separate fridge candidate work; its projection is uncalibrated and is not part of the Blender verification below.

Both Blender candidates use the fixture blueprint dimensions from `data/fixtures/mvp_v1.json`, the shared `iso2x_v1` camera, and the same crop/anchor per rotation across stock states. Their `validation_report.json` files record measured camera-marker projection within the spec tolerance and image-layer consistency (48 files per fixture). This does **not** verify mesh silhouette dimensions, natural product placement on every visible shelf face, image quality, Godot import/rendering, occlusion, or zoom behavior. The contact sheets expose placement/visual defects in some rotations; treat them as work-in-progress and do not use at runtime.

## Reproduce

From repository root, using Blender 2.91 and Python with Pillow and NumPy:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 2.91\blender.exe' -b --python tools/assets/render_shelf_inventory_states.py -- --fixture shelf_general --out build/shelf_general_states
python tools/assets/build_shelf_inventory_states.py --raw build/shelf_general_states --out assets/source/textures/fixtures/inventory_state_candidates/shelf_general_blender_v2
python tools/assets/validate_inventory_state_candidate.py assets/source/textures/fixtures/inventory_state_candidates/shelf_general_blender_v2 --report assets/source/textures/fixtures/inventory_state_candidates/shelf_general_blender_v2/validation_report.json
```

Replace `shelf_general` with `shelf_noodle` and the output folder with `shelf_noodle_states` / `shelf_noodle_blender_v1` to reproduce the noodle candidate. See each fixture's `provenance.json` and `manifest.json` for settings, dimensions, anchors, states, and file hashes.

## Acceptance still required

The products are simple colored low-poly cartons, not finished branded packaging. Visually review and correct the 3D placement/silhouettes in all four rotations, produce final category-specific package art, compare at zoom 0.5/1/1.6/2, and verify in Godot with fixture/person occlusion before changing runtime approval. No Claude-owned Godot files were changed.
