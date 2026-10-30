# shelf_general FULL direct-edit candidate v2

- Producer: Codex built-in ImageGen direct edit, 2026-10-30.
- Original: `gondola_edit_v2.png`, 1254×1254 RGBA, 1,001,209 bytes, SHA-256 `98a9f93b0fbf6938de7020b7e26508b2bd615e1917c0df6c9e98d4e4855dc5ca`. Preserved unchanged.
- Image 1: empty shelf v13 geometry/camera guide. Image 2: game style reference only.
- The dark base is empty and inventory remains on four visible shelf rows. Gross alpha outline closely follows the guide.

## Focused QA — FAIL (review only)

- Whole alpha mask IoU against the EMPTY guide is 0.987027; comparison keeps original canvas sizes and has no crop/resize. The mask includes goods and does not prove fixture-only geometry.
- Alpha>127 bbox `[161, 146, 822, 1083]`; L/R/T/B margins 12.84% / 34.45% / 11.64% / 13.64%. Top is 0.36 percentage points below the 12% target.
- Product fronts read well, but pouches/cups still show noticeable thickness. Fixture-only control points, anchor, projection calibration and Godot display are unchecked.
- `runtime_approved:false`; no runtime files modified.

## Prompt

Use case: stylized-concept. Edit the empty fixture in Image 1, not a new scene. Treat the exact white shelf boards, central upright, side supports, back panels, dark plinth, camera and transparent canvas as locked, immutable pixels. Add only small fictional Japanese snack and bread package fronts to the existing WHITE shelf boards, above the dark plinth. The plinth/base must remain completely bare and unchanged. There are exactly four existing selling shelf levels; add products only on those levels, fitted within each board's existing front/back boundaries. Do not add, remove, resize, tilt, move, or redraw any fixture part; do not change the camera framing or scale. Keep goods as one integrated shelf sprite, not detached package cards. Make packaging front-facing, compact, near-flat with almost no visible side/top volume. Do not create goods on the floor, base, shelf top, hidden reverse side, or outside edges. No additional shelves, no header, roof, canopy, loose objects, text, logo, ground shadow, glow, or vignette. Image 2 is a style guide only for hand-painted convenience-store game illustration. Preserve transparency. Keep at least 15% empty alpha margin on every image edge.
