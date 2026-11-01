# Cup-noodle gondola FULL — ImageGen review candidate

- Asset ID: `shelf_noodle_gondola_FULL_v1`
- Review only; `runtime_approved: false`
- Source: Codex built-in ImageGen, 2026-11-01; original saved unchanged at 1254×1254 RGBA.
- Source SHA-256: `5241f601690cf33626d90e4193e0dbbb729ee3153fa60fd3d7c14ec1c77a26b5`.
- Reference roles: existing open cup-noodle shelf only for shelf/category context; bread gondola only for rendering style.
- `sprite_padded_review.png` is a separate 1800×1800 canvas-only derivative; no source pixels resampled. SHA-256: `bb68eabf8e6aae95ed9939fa8948b665f28be0a1d64a814d010670e139653431`.
- `preview_checkerboard.jpg` shows alpha on a checkerboard; SHA-256: `d6ce3e727514f3e2761e9ea9ee361680a916af493c03d6a176d7d05c00253bff`.

## Focused visual QA

- Integrated fixture and merchandise: PASS. Four visible shelf levels are stocked with cylindrical cups and lidded noodle bowls; items rest on shelves and behind retaining rails.
- Product category/front recognition: PASS at source resolution. Cup side labels and bowl lids are distinct; colors and food illustrations communicate cup noodles.
- Cuboid product failure: NOT OBSERVED. Package forms are cylindrical/rounded bowls, not rectangular merchandise blocks or floating cards.
- Dense FULL presentation: PASS visually, with a review note: multiple front-to-back rows make the gondola appear deep. The fit to the intended shallow shelf is unverified and may require a different source image, not content scaling.
- Raw alpha >8 margin: FAIL. L/T/R/B = 13.48% / 7.89% / 13.32% / 5.42%; required minimum is 12%. At alpha >0, faint pixels touch the left and bottom borders.
- Canvas-only 1800×1800 derivative: alpha >8 margins L/T/R/B = 24.56% / 20.67% / 24.44% / 18.94%; alpha >0 margins = 15.17% / 16.33% / 16.83% / 16.06%. Margin gate passes on this derivative, but it changes apparent sprite scale; target game scale is not inferred.
- Exact iso2x slope, r0 access side, world dimensions, footprint, ground anchor, 4-direction suitability, and Godot display scale: NOT VERIFIED.
- Independent visual reviewer and user approval: pending. Not for runtime use.

See `prompt_record.txt`, `qa.json`, and `asset_candidate.json` for the full provenance and gate status. `make_review_previews.py` reproduces the derived preview files without modifying the original.
