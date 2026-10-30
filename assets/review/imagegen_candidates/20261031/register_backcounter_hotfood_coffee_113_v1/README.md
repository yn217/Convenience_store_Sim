# Register back-counter hot-food and coffee vignette — ImageGen review candidate

- Asset ID: `register_backcounter_hotfood_coffee_113_v1`
- Target: Issue #113 counter-area density. This is a visual vignette candidate for the existing back-counter set, not a new runtime fixture definition.
- Generated with Codex built-in ImageGen on 2026-10-31. `source_original.png` is byte-preserved from the tool output.
- Depicts a hot-snack heated glass case beside a coffee machine, with product/POP shelves behind and a shared grounded base. No people or cashier counter are included. Generic packaging and no legible trademarks.
- Content QA: PASS as a concept image; heated food, coffee service, shelves and consumables are visible and read as one related service area.
- Alpha QA: FAIL. Broad semi-transparency; only 537 pixels are fully opaque and 1,117,533 pixels have alpha 128–254. Nonzero alpha touches left and bottom edges (7 and 53 pixels).
- Framing QA: FAIL. Although thresholded alpha>=128 has a 6px bottom margin, low-alpha pixels touch the bottom edge; safe transparent margins are not preserved.
- Projection QA: FAIL for calibrated `iso2x_v1`; this is an uncalibrated three-quarter perspective illustration. No control points or Godot comparison are available.
- Dimensions, world footprint, ground anchor, access, actual game scale and occlusion are NOT CHECKED.
- No staffing, sales, price, SKU or runtime behavior is implied. `runtime_approved:false`; review-only.
- The tool did not expose an ImageGen model/version.

`qa_preview_white.jpg` is a diagnostic white-matte composite; it does not replace or edit the original.
