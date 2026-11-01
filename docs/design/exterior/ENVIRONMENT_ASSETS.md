# Exterior environment assets — 2026-10-26

`green_street_tree_v1` is a painted green street-tree candidate for the target mockup's dense, warm green landscape. It is separate from the existing cherry-tree assets and does not replace them globally.

## Integration contract

- Consumer: existing `PropSprites.texture("green_street_tree_v1", rotation)` and `StoreDecor` sprite ops.
- Canvas 720×720 source px, ground/root anchor (360, 639), source scale 2. Draw using `IsoProjection.sprite_top_left`, with size × zoom / 2. No per-instance scaling.
- Ground units: metres. Nominal crown 2.8×2.8 m, height 3.5 m; one-tile root footprint. Trees remain static scenery outside walkable floor and entrance clearance.
- All four rotation entries intentionally reference the same upright natural tree image. This is acceptable only for approximately radial trees, never for directional furniture.
- Place behind the store on the rear edges for the first visual QA. Near-edge placement requires checking canopy overlap with shelves and window visibility.
- Sorting follows the existing exterior/front layer and `rank`, then world x+y. No new z-index, input surface, collision or save field.
- Generated art has no cast shadow; use a separate ground-plane contact shadow in the environment renderer. Do not paint a screen-space shadow into the canopy image.

## Existing assets and outstanding work

The accompanying `environment_asset_specs.json` records the same fields for the reusable planter, vending machine, bench and bicycle rack. Their current variants are procedural and have not been relabelled as final painted assets. The target has planted flower beds, detailed vending contents and recognisable bicycles; those still require new image candidates and in-game review.

## Production and QA

Built-in imagegen produced a tree, then a targeted refinement of edge colours. `PROVENANCE.json` records the prompt and limitations. The source is retained under `assets/source/exterior`. `python tools/assets/package_exterior_tree.py` reproducibly performs uniform resampling and alpha-preserving canvas placement only.

The source and packaged image were visually inspected. Packaging checks RGBA transparency, the root anchor and the upper border. Some very low-alpha colour remnants persist in the generation, so acceptance depends on a game screenshot over the actual pavement at normal and high zoom. No live-game integration or performance claim is made by this asset-only change.
