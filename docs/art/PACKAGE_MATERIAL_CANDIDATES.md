# Package and fixture material candidates

This change records source-art candidates for Issues #12 and #61. It does not
change Godot scenes, presenters, domain code, runtime manifests, or the
procedural shape system.

## Candidate set

- `assets/source/textures/packages/sku_onigiri_comparison_v01.png`: two fictional onigiri label directions.
- `assets/source/textures/packages/sku_tea_comparison_v01.png`: two fictional tea label directions.
- `assets/source/textures/packages/sku_cupnoodle_comparison_v01.png`: two fictional cup-noodle label directions.
- `assets/source/textures/materials/register_basic_material_comparison_v01.png`: two register material directions.
- `assets/source/textures/materials/shelf_general_material_comparison_v01.png`: two general-shelf material directions.
- `assets/source/textures/materials/fridge_drink_material_comparison_v01.png`: two refrigerated-case material directions.
- `docs/art/package_material_candidate_contact_sheet.png`: review contact sheet.

Each source board is a comparison reference, not a final four-direction
iso2x sprite. The left/right concepts must be cropped, corrected, and reviewed
before any runtime adoption. Product artwork is intended as a slot/overlay
input; it must not be baked into a fixture body.

## Reproduction

1. Use the built-in image generation tool with the exact prompts recorded in
   `assets/source/textures/CANDIDATE_PROVENANCE.json`.
2. Preserve the generated board as the source candidate.
3. Run `python tools/art/build_candidate_contact_sheet.py` from the repository
   root to rebuild the review sheet.
4. Crop and correct one selected concept per SKU, then render the required
   four directions through the shared Blender or equivalent iso2x pipeline.

The contact sheet is a source-level before/after decision aid: the previous
state is the procedural placeholder/material block, and these boards are the
new art candidates. It is not evidence of Godot runtime integration.

## Acceptance status

- Actual PNG source files: complete for this candidate batch.
- Three SKU families with two directions each: complete as source boards.
- Three baseline fixture material families with two directions each: complete as source boards.
- Trademark and readable-brand review: pending; all prompts requested fictional marks only.
- #29 provenance/license review: pending.
- Texture crop, alpha cleanup, iso2x four-direction render: pending.
- Godot integration and #26 depth composition: intentionally deferred to the
  implementation owner / follow-up PR.
