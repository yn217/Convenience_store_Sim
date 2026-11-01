# Hot-food / coffee checkout counter — ImageGen review candidate

- Asset ID: `register_hotfood_coffee_counter_FULL_v1`
- Review only; `runtime_approved: false`
- Source: Codex built-in ImageGen, 2026-11-01.
- Main image: `source_original.png`, unchanged, 1254×1254 RGBA.
- SHA-256: `7e72cc1531df8ebb57059e54b32bb1c7d65b9e9d82329e557325c5f69b4a3e1d`
- References: existing combined hot-food/oden counter for category context; a bread-gondola candidate for illustration style only.
- `sprite_padded_review.png`: 1800×1800 canvas-only QA derivative; source pixels are not resampled. SHA-256: `235202601b438a75f509a5ca1627a0efb1cc0617764f5f3bb962d18a96fa6027`.
- `preview_checkerboard.jpg`: transparency inspection composite; SHA-256: `9768e381b857ddfd750bbc9440ac3bacc2c2c658d7d83bf76e1ea76cfbd9455a`.

## Focused visual QA

- Integrated service-counter composition: PASS. One counter supports a hot-food warmer, checkout terminal/printer, and coffee brewer/cup station.
- Item support/contact: PASS by visual inspection; appliances sit on the counter, food sits in trays inside the warmer.
- Product treatment: PASS. Food appears as contained food shapes, with no floating package cards or merchandise cuboids.
- Content and silhouette: PASS for a compact hot-food + checkout + coffee counter; generic surfaces contain no legible branding or copied labels.
- Source-image alpha margin: FAIL. At alpha >8, margins L/T/R/B are 6.30% / 20.18% / 4.94% / 6.22% (minimum 12%). At alpha >0 the bbox reaches the left and bottom canvas edges; edge maxima top/bottom/left/right = 0/1/1/0.
- `sprite_padded_review.png`: canvas-only padding to 1800×1800; no image resampling or content edits. Its measured alpha >8 margins are L/T/R/B = 19.56% / 29.22% / 18.61% / 19.50%; alpha >0 margins = 15.17% / 17.00% / 18.50% / 15.17%. This resolves the transparent-margin gate for review while changing the overall sprite canvas and apparent scale.
- `preview_checkerboard.jpg` is a visual transparency preview. `make_review_previews.py` reproducibly creates the two derived previews; it does not modify `source_original.png`.
- Iso2x projection, world width/depth/height, tile footprint, ground anchor, 4-direction compatibility, and actual Godot display scale: NOT VERIFIED. The counter is elongated and should not be assumed to fit a fixture contract based only on the illustration.
- Independent reviewer and user approval: pending. Not for runtime use.

See `asset_candidate.json` for the review contract and `qa.json` for machine-readable measurements.
