# shelf_general FULL dense v3 — ImageGen review candidate

- Asset ID: `shelf_general_open_r0_full_dense_v3`
- Generated with Codex built-in ImageGen on 2026-10-31. Original PNG is copied byte-for-byte to `source_original.png`.
- Targeted follow-up to v2: reduced faint nonzero alpha at the canvas edge from 52 to 6 pixels, and requested 2:1 axis slopes plus an 8% transparent margin.
- Visual content: four stocked display levels with integrated front-facing packages. The pale upper back structure and some visible shelf surfaces are still broad. This is not a geometry-approved canonical.
- Projection remains uncalibrated against actual project control points and Godot. Prompted slopes alone do not establish a projection PASS.
- Alpha report counts all levels; six border pixels still have alpha 1, so edge-alpha QA remains FAIL. No pixels were edited in the source.
- `runtime_approved:false`; review only.

- Same-size side-by-side diagnostic: `shelf_general_open_r0_full_dense_v2-v3_comparison.png`; it is not a projection or in-game comparison. Edge alpha decreased from 52 to 6 pixels, but remains a fail.
