# Chilled sandwich case FULL — ImageGen review candidate

- Asset ID: `fridge_sandwich_case_FULL_v1`
- Review only; `runtime_approved: false`
- Source: Codex built-in ImageGen, 2026-11-01; original retained unchanged at 1254×1254 RGBA.
- Source SHA-256: `595a9c2412696eac8d140d69794c624810bc4b39e7c34ace7679aa20db1c94ac`.
- Reference roles: existing chilled sandwich case for category/context only; bread gondola for illustration style only.
- `sprite_padded_review.png` is a separate 1800×1800 canvas-only derivative (no resampling); SHA-256: `8e6d7ee0f9c77641bbb259b13adc65782bebf3305df7dbc243f44befcab40e7c`.
- `preview_checkerboard.jpg` shows transparency; SHA-256: `217356fcbbe794e93fb7cd8d2bf58511cdb6b9ed99ae5c6c0b8d65c51710a46e`.

## Focused visual QA

- Integrated fixture/products: PASS. A two-door chilled case contains four visible shelves with sandwiches, rolls and salad cups.
- Category and product fronts: PASS at source size. Triangular sandwich packs and food fillings are visible through the glass; restrained labels do not dominate.
- Product support and cuboid failure: PASS. Merchandise rests on shelves and reads as wrapped food/trays, not floating cards or thick blocks.
- Shape review note: top cap/roof face looks broad relative to the merchandise bay; the cabinet also appears deep. Compare with the actual target case before any projection/scale calibration. Do not shrink or stretch to conceal a structural mismatch.
- Raw alpha >8 margin: FAIL. L/T/R/B = 11.64% / 9.01% / 9.89% / 1.12%; minimum required is 12%. At alpha >0 the source reaches left and bottom edges.
- Canvas-only 1800×1800 derivative: alpha >8 margins L/T/R/B = 23.28% / 21.44% / 22.06% / 15.94%; alpha >0 margins = 15.17% / 15.39% / 17.50% / 15.17%. Margin gate passes on this separate derivative; its apparent sprite scale changes.
- iso2x slope, camera direction, world dimensions, tile footprint, ground anchor, 4-direction views and actual Godot display size: NOT VERIFIED.
- Independent art review and user approval: pending. Not for runtime use.

Full prompt, provenance and machine-readable gates are in `prompt_record.txt`, `qa.json` and `asset_candidate.json`. `make_review_previews.py` regenerates only the canvas-padded and checkerboard previews; it never changes the original.
