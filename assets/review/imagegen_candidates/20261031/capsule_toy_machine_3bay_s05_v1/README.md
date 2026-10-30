# Three-bay capsule toy machine — ImageGen review candidate

- Asset: `capsule_toy_machine_3bay_s05_v1`
- Generated with Codex built-in ImageGen on 2026-10-31. The original PNG is kept byte-for-byte as `source_original.png`.
- The image depicts three joined bays; each has a capsule globe, visible capsules, a turning knob and a retrieval hatch. The mascot decals are generic, with no legible brand text.
- Content QA: PASS for a visual concept candidate. Exactly three bays and their key controls are visible.
- Alpha QA: FAIL. The canvas is 1305×1205 RGBA, but only 277 pixels are fully opaque; 1,145,740 pixels have alpha 128–254. Nonzero alpha touches the top, left and bottom edges (50/11/67 pixels respectively). The background/subject matte is broadly semi-transparent and unsuitable as a clean game cutout.
- Framing QA: FAIL. The thresholded subject reaches y=1204 on the 1205px canvas; the lower silhouette has effectively no safe margin. Do not crop or scale to hide it.
- Projection QA: FAIL for calibrated `iso2x_v1`. This is a perspective-like three-quarter illustration, not a verified orthographic game projection. No control points or Godot overlay are available.
- Dimensions, world footprint, anchor, customer access and Godot display size: NOT CHECKED.
- No pricing, SKU behavior, inventory synchronization, collision, or runtime use is implied. `runtime_approved:false`; review-only.
- Generation model/version is not exposed by the image tool.

`qa_preview_white.jpg` is only a diagnostic white-matte composite; it is not a replacement source asset.
