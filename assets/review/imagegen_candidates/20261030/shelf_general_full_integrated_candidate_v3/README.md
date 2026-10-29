# shelf_general FULL integrated candidate v3

- Producer: image-generation subagent `Copernicus` using GPT-6 Luna; generated 2026-10-30.
- Source: `shelf_general_full_integrated_candidate_v3.png`, 1254×1254 RGBA, 1,540,831 bytes. Source bytes are preserved unchanged; no crop, resize, recolor, or mask cleanup.
- SHA-256: `6486fc8e63c172dad61598d6ca65dc6bfb408424ed4958b577129bf09d337626`.
- References: EMPTY styled v13 as strict structure base, the iso2x_v1 projection guide, and FULL v2 for product artwork only.
- Prompt brief sent: add fictional product package fronts to the four existing shelf faces while preserving v13 shelf geometry; products should be thin, no sidewalls/box depth; require 15% transparent margin; remove background/glow. The image-generation service's exact internal prompt was not retained.

## Focused review: FAIL

- Shelf and goods are composed into a single image, and product package faces are colorful.
- The resulting shelf differs visibly from v13: shelf surfaces/depth and outer structure have changed, with an oversized blank upper/deck surface.
- Packages and display still have strong visible side volume. Product thickness/box-like appearance remains a failure.
- The long shelf-edge projection differs from the guide's iso2x_v1 direction; no valid control-point calibration was obtained.
- Source canvas is 1254×1254; alpha>127 bounds are `[116, 58, 966, 1207]`. Margin percentages: {'left': 9.25, 'right': 22.97, 'top': 4.63, 'bottom': 3.75}. Bottom margin is extremely small; the safe 12% margin fails. A light edge halo is visible on checkerboard.
- `comparison_empty_v13_full_v3.png` uses same-size source canvases; `alpha_preview_v3.png` composites on white/checkerboard. Source is unchanged by these previews.
- Intended contract: `shelf_general`, 1×2 tiles, 0.92×1.92×1.50m, access E. Real dimensions, anchor, Godot view and EMPTY/HALF synchronization are unverified.
- Keep review-only: `runtime_approved:false`.
