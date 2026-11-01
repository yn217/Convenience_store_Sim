# shelf_general FULL flatter-package candidate v4

- Producer: Codex built-in ImageGen edit, 2026-10-30.
- Source: `gondola_edit_v4.png`, 1254×1254 RGBA, 869,072 bytes, SHA-256 `81e496d7235d5050ffb6949e2f361fd8f1f26ffe40100df3eeef1687341be733`; original preserved unchanged.
- Edit source: integrated FULL v3; reference: game style screenshot only.

## Focused QA — FAIL (review only)

- One integrated shelf+goods sprite; four rows are populated and the plinth is empty. The same-canvas review still shows products concentrated on the right half while broad empty shelf boards extend left. This is a major composition/structure mismatch, and cups/baked goods still read as volumetric objects.
- Alpha>127 bbox `[161, 143, 825, 1096]`; L/R/T/B margins 12.84% / 34.21% / 11.4% / 12.6%. The top remains below the 12% target.
- Whole-mask IoU: 0.990863 vs v3, 0.963271 vs EMPTY guide. Both include goods and do not certify fixture-only geometry or meaningful shape agreement. No control points, anchor or Godot display have been checked.
- Same-canvas comparison is unscaled and uncropped. `runtime_approved:false`.

## Prompt

Use case: stylized-concept, flat 2D game sprite. Edit Image 1 for the same shelf_general FULL candidate. Preserve exactly: shelf silhouette and all visible boards/supports/base, four product rows, camera and projection, canvas, scale, object position, alpha bounds, and each product's position/size. The dark plinth stays completely empty. Change only the product rendering into flat printed package illustrations: each package should be a thin front-facing printed face with graphic colors and simple painted food icons, no side panels, top flaps, bevels, highlights that imply thickness, cast shadows, deep perspective, or 3D/cuboid volume. Keep the packages continuous and neatly aligned along the existing shelf rows. Keep the existing open gondola and visible selling face. Image 2 is style reference only; use a soft hand-painted 2D isometric game illustration, not photoreal 3D. No readable text, logos, brands, background, floor, extra shelves, header, roof, or new objects. Preserve transparent background and all fixture geometry. Do not crop, resize or shift the subject.
