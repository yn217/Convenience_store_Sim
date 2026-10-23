# Customer art candidates (Issue #23)

This board is a source-art candidate for the customer sprite work in Issue #23. It contains three fictional adult variants: casual hoodie and tote, office worker with shoulder bag, and older adult with cardigan and basket.

![Customer variants](../../assets/source/textures/characters/customer_variants_comparison_v01.png)

The equal-third crops are reproducible with `tools/art/split_customer_candidates.py` and are listed in `assets/source/textures/characters/CANDIDATE_CROPS.json`.

A first transparent cutout pilot is stored at `assets/source/textures/characters/candidates/customer_casual_tote_cutout_v01.png` (1024x1536 RGBA). It is a source-art pilot, not a production sprite: scale, anchor, shadow, and direction consistency still require review.

## Prompt record

`Create a clean game-asset concept comparison board for a realistic-leaning 2.5D isometric Japanese convenience-store simulation. Show three distinct fictional adult customer character variants standing separately on a neutral light background: (A) casual young adult with hoodie and tote bag, (B) office worker with neat shirt and shoulder bag, (C) older adult with cardigan and shopping basket. Each character should be shown in a consistent 3/4 isometric standing pose with clear feet contact, readable silhouette, modest natural proportions, soft studio lighting, muted convenience-store palette, no readable text, no logos, no copyrighted characters. Arrange as three equal columns with large spacing, front-facing toward camera, suitable as an art-direction reference board. Square 1024x1024 composition.`

Tool metadata such as model and seed was not exposed. The provenance file records that limitation. The board is not a 4-direction sprite sheet, animation set, or Godot integration; those remain pending against the Issue's completion criteria.

## Review gate

- [x] Actual generated image file stored in the repository
- [x] Fictional/no-logo/no-readable-text direction recorded
- [x] Provenance record present
- [ ] Human selection of the three variants
- [ ] Four directions and animation frames
- [ ] Common anchor, scale, shadow, and occlusion validation
- [ ] In-game screenshots and focused tests
