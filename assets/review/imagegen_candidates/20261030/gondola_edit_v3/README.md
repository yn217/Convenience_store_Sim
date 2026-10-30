# shelf_general FULL direct-edit candidate v3

- Producer: Codex built-in ImageGen direct edit, 2026-10-30.
- Source: `gondola_edit_v3.png`, 1254×1254 RGBA, 917,592 bytes, SHA-256 `697b608c6ff14a673e287e9e2bb6936109bfa8d97655192a8193f0ea40fbcf54`; original is preserved unchanged.
- Edited from integrated FULL v2 to flatten product artwork; EMPTY v13 geometry and the game screenshot remain comparison/style references.

## Focused QA — FAIL (review only)

- The four visible shelf levels are stocked and the plinth remains empty. Product faces are flatter and clearer than v2, but edge/top volume is still visible on some packages and cups.
- Alpha>127 bbox `[160, 144, 824, 1093]`; L/R/T/B margins 12.76% / 34.29% / 11.48% / 12.84%. Top is below the 12% safe-margin target.
- Whole-mask IoU: 0.983042 vs v2, 0.970807 vs EMPTY guide; both include products and do not prove fixture-only geometry. Control points, anchor and Godot display are unchecked.
- Same-canvas comparison is unscaled and uncropped. `runtime_approved:false`.

## Prompt

Use case: stylized-concept. Precisely edit Image 1 for a Japanese convenience-store game sprite. Preserve the full shelf, every shelf board and upright, dark base, camera/projection, framing, placement, scale, existing alpha silhouette and all product positions. Change only the visual treatment of the products: make every bag/carton/cup/bakery package read as a flat 2D painted package front, with almost zero visible side or top planes, no box extrusion, no deep perspective, no thick cuboid appearance. Use simple hand-painted game illustration and clear colorful package-front graphics, no readable text or logos. Keep the existing four shelf rows fully stocked and keep the dark plinth completely empty. Do not add, remove, move, resize or reshape any products or fixture parts. Do not add a new header, shelf, background, ground, glow, shadow or vignette. Edit only products' front-face artwork to flatten their appearance; all shelf geometry and layout must remain fixed.
