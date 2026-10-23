# Package candidate handoff to the iso2x pipeline

This document is the handoff boundary between the completed source-art
staging work and the still-pending Blender/Godot work in Issues #8, #9, #12,
and #26.

## Inputs ready

- Six reviewed source candidates in `assets/source/textures/packages/candidates/`.
- Six normalized `*_cutout_v02.png` files with transparent background,
  bottom contact, and 8 px side/top staging padding.
- Six `*_source256_v01.png` files in `source_256/` with 256×256 RGBA canvas.
- `SOURCE_CANVAS_MANIFEST.json` with source paths and provisional bottom anchors.
- `CANDIDATE_VISUAL_ID_MAP.json` with review-only links to existing IDs.

## Required pipeline work

1. Select one approved variant per target visual ID after human mark/text and
   license review.
2. Bind the selected image to the existing reusable product shape; do not
   bake SKU art into a shelf or fixture body.
3. Use the common `iso2x_v1` camera and the existing product shape dimensions.
4. Render directions 0, 1, 2, and 3 from the same 3D source. Do not rotate or
   mirror a single 2D image as a substitute.
5. Preserve the product slot anchor and the 256×256 source-canvas convention.
6. Update only the review branch manifest after image, crop, anchor, and
   fallback checks pass. Keep the procedural visual ID available for rollback.
7. Validate empty/low/medium/full composition through the existing overlay
   path, then perform Godot depth and glass checks under #26.

No Blender executable was available in the current local environment during
this staging pass, so no four-direction render is claimed here.
