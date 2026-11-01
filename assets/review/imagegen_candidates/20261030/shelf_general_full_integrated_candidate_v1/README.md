# shelf_general FULL integrated 2D review candidate v1

- Asset: `shelf_general_full_integrated_candidate_v1`
- Requested/actual: Japanese convenience-store ambient gondola, FULL; shelf and packages are one composed sprite image.
- Producer: image-generation subagent `Jason` (`gpt-6-luna`); generated 2026-10-30.
- Original: `shelf_general_full_integrated_candidate_v1.png`, 1536×1024 RGBA, 2,170,939 bytes. Preserved byte-for-byte after generation; no crop, resize, repaint, or background cleanup was applied.
- SHA-256: `0f7c425838189223073e1a60696af58c8a032de3ce6ec966076738a1f305fa59`.
- Generation brief: new single-view image of a Japanese single-sided ambient gondola, integrated with dense fictional snack/bread/carton packages; iso2x-like shallow isometric; transparent background; complete dark base; no floating separate package cards and no thick cuboid products. The lower-level prompt emitted internally by the image tool was not returned; this brief records the instructions sent to the producing agent.

## Focused QA

- The goods and shelf are baked together into one sprite; this follows the requested integrated-composition approach.
- Visual review finds strong package side-volume, especially the bottom row's carton-like packs. This conflicts with the no-cuboid product rule and fails.
- Shelf long-edge projection appears much shallower than the game's ±0.5 screen slope; no reliable matching control points or anchor were established. Projection fails.
- Alpha >127 bounds are `[345,24,1342,1013]` on 1536×1024: top margin 2.3%, bottom 1.1%, below the 12% safe-margin target. 53.799% pixels are fully transparent; alpha fringe remains around the sprite. Alpha is partial/fail for adoption.
- White-matte and checkerboard-alpha composites are in `alpha_preview_v1.png`. These are QA derivatives only; the source image is unchanged.
- Intended fixture contract for follow-up: `shelf_general`, 1×2 tiles, 0.92×1.92×1.50 m, access edge E. Dimensions, anchor, world orientation, Godot display size, and EMPTY/HALF state consistency are unverified.
- Decision: review-only; do not use at runtime. `runtime_approved:false`.

## Instructions sent to the image-generation agent

Generate one new `shelf_general FULL` integrated 2D candidate. Do not overwrite existing EMPTY v13. The user forbids placing separate floating flat package cards on a shelf and forbids thick cuboid/rectangular-block product objects. Create a Japanese convenience-store single-sided open ambient gondola, rectangular 1×2-footprint proportion, four shallow shelves, dark base, restrained header. Aim for the game's `iso2x_v1` shallow 2:1 isometric direction. Compose fictional snack/bread/small package fronts densely along all shelves as one image with the shelf, with no separate floating objects. Use transparent background, keep the entire fixture and base in frame with safe margins, and avoid clipping. Generate one image only; review only; do not edit Godot/Renderer, existing candidates, or Git state.
