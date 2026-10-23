# Fixture sprite pipeline (Issue #8)

Blender Python renders every fixture from the same camera preset **`iso2x_v1`**
(orthographic, azimuth 45°, elevation 30°, 2× source scale), then a second step crops, anchors and
describes the sprites in a manifest that follows `docs/schemas/visual_manifest.schema.json`.
Normative sizes: `docs/implementation/02_GRID_AND_ASSET_CONTRACT.md` and `06_ASSET_BLUEPRINTS_AND_VALIDATION.md`.

| File | Runs in | Role |
|---|---|---|
| `iso2x.py` | anywhere | projection + rotation math (`+X → (+128,+64)`, `+Y → (−128,+64)`, `+Z → (0,−156.767)` source px) |
| `blueprints.py` | anywhere | boxes per fixture type, 3D display-slot positions, size checks |
| `render_fixtures.py` | **Blender** | scene/camera/light/material preset, calibration markers, full-canvas layer renders, mesh bbox |
| `build_sprites.py` | Python + Pillow + numpy | one shared crop per direction (+8 px padding), `anchor_px`, slot anchors, manifest, `PROVENANCE.json` |
| `validate_manifests.py` | Python + Pillow + numpy | the mechanical gate (calibration, schema shape, files, canvas, anchors, silhouette, sizes) |
| `contact_sheet.py` | Python + Pillow | all rotations side by side with anchor and footprint outline, for the eyeball check |

All ten initial types are modelled (#8, #22): the 1x1 `warmer_oden`, 2x2 `freezer_ice`, and the 1x2 `register_basic`, `shelf_general`, `shelf_onigiri`, `shelf_noodle`, `shelf_bread`, `shelf_snack`, `fridge_drink`, `fridge_dessert`.

## Regenerate everything (Windows)

```powershell
$blender = "C:\Program Files\Blender Foundation\Blender 2.91\blender.exe"   # tested: 2.91.0

# 1. render (about 35 s) – writes build\asset_raw\ (git-ignored)
& $blender -b --python tools/assets/render_fixtures.py -- --catalog data/fixtures/mvp_v1.json --out build/asset_raw

# 2. crop + manifests -> assets/generated/fixtures/
python tools/assets/build_sprites.py --catalog data/fixtures/mvp_v1.json --raw build/asset_raw --out assets/generated/fixtures

# 3. gate (also part of tools\run_tests.ps1)
python tools/assets/validate_manifests.py

# 4. eyeball check
python tools/assets/contact_sheet.py --dir assets/generated/fixtures --out build/sheet.png
```

`--types a,b` on step 1 renders a subset. Paths are made absolute inside the script because
Blender resolves relative render paths against the drive root.
Python deps for steps 2–4: `pip install pillow numpy`.

## Rules the pipeline enforces

* One camera, one light set, one colour-management setting (Standard, no look, no dither) for **every**
  asset. There is no per-asset scale, exposure or stretch; sprite size follows the real model size.
* The camera is calibrated in every batch: four 4 cm markers (origin, +X, +Y, +Z) are rendered and
  measured. `validate_manifests.py` re-measures the committed `calibration/iso2x_v1_calibration.png`
  and fails unless X/Y are within 1 px and Z within 2 px (source px). Without it no asset passes.
* Models are rotated in 3D (quarter turns about the cell origin, then moved so the min cell is the new
  origin). The camera never turns and images are never rotated.
* All layers of a direction (`body`, `shadow`, `glass_front`) share one crop rectangle, so `canvas_px`
  and `anchor_px` are identical for them. `anchor_px` = world (0,0,0) projection − crop top-left.
* PNG canvas sizes differ per asset and direction; that is expected.
* Display slots are positioned in 3D and rotated with the model, then projected (`slot_anchors_px`).

## What the validator checks

calibration · manifest structure (unknown fields, id/path patterns, four rotations) · catalog
`footprint`/`dimensions_m` · referenced PNGs exist, are RGBA and match `canvas_px` · anchors, slots and
polygon inside the canvas · ≥ 8 px padding · **rendered silhouette vs projected blueprint within 2 source px
(= 1 screen px at zoom 1.0)** · Blender-measured mesh bbox (≤ footprint − 0.08 m, inside footprint − 0.04 m,
height ±0.01 m, equal to the blueprint) · slots lie on the customer-facing side.
`python -m unittest discover -s tests/tools -v` proves it also *fails* on tampered copies.

## Product shape overlays (Issue #12 / #26)

Product art is generated as eight reusable container shapes, not as 24 baked shelf images.
The category-to-shape mapping is written to `assets/generated/products/products_manifest.json`.
Each shape has four deterministic direction variants and generic fictional labels only.

```powershell
python tools/assets/build_products.py
python tools/assets/validate_products.py
python tools/assets/compose_product_lod.py
```

`validate_products.py` checks the 8 shapes, RGBA 256×256 source canvases, four directions,
all 24 catalog visual IDs, and every referenced file. `compose_product_lod.py` creates an
asset-only preview for `empty/low/medium/full` display states using the fixture manifest's
slot anchors. Runtime integration should use `ProductSprites` and `ProductOverlayPlan`; the
preview does not alter game state and does not replace the Godot presenter.

## Reproducibility and its limits

`PROVENANCE.json` records the Blender version, engine, samples, view transform and a hash of the four
scripts. The same Blender build on the same GPU/driver reproduces the images; a different GPU or
Blender version may change pixels slightly (Eevee), which is why the gate uses tolerances, not hashes.

## Not done here

Final art quality (glass, materials, label rails) needs a human look (#9 reference assets).
Product sprites are composed from slot anchors; they are not rendered per SKU.

## Customer sprites (Issue #23)

Same camera preset and light set as the fixtures; the figures are boxes posed in 3D (`figures.py`) and turned by quarter turns before rendering (no mirrored or rotated images).

```powershell
& $blender -b --python tools/assets/render_customers.py -- --out build/asset_raw_customers   # about 45 s, 3 variants x 4 facings x (walk 6 + idle 2 + inspect 4) frames
python tools/assets/build_customers.py --raw build/asset_raw_customers --out assets/generated/characters
python tools/assets/validate_customers.py        # part of tools\run_tests.ps1
```

All frames of a variant share one crop, one canvas and one anchor (the feet), so the feet never move between facings or frames. `validate_customers.py` re-measures the calibration image and checks the 14 §2 frame counts and rates, canvas/anchor, padding, body height against `height_m`, and ground contact. The body-height boxes are a stand-in for the AI/hand-made art of #12.
