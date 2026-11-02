# Open ambient gondola FULL v5 — review only

- Asset: `shelf_general_open_r0_integrated_FULL_v5`, target fixture `shelf_general` (1×2 tiles).
- Generated with built-in Codex ImageGen using three local references: corrected EMPTY geometry, target game screenshot/style, and `iso2x_v1` structure guide. Original output was copied unchanged to `source_original.png`.
- Four stocked sales decks are visually present; no top canopy. Goods are integrated into the shelf image rather than separate floating cards.
- Preliminary QA: long-edge Hough slopes are approximately −0.52 and +0.56 versus target ±0.50; this is an image-level estimate, not a Godot calibration. Bottom alpha margin at threshold 8 is only about 5.8%, below the 12% gate; a few alpha=1 pixels touch the bottom edge. The shelves/base still read deep and the backing panel is large; shape needs review against the compact EMPTY reference. Appearance is more glossy/render-like than the game screenshot.
- Exact 1×2 world bounds, pivot, r0 direction, game zoom, occlusion and runtime appearance are unverified. Candidate remains `runtime_approved:false` and must not be used in runtime.