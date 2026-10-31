# Compact two-seat eat-in table — ImageGen review candidate

- Asset ID: `eat_in_two_seat_table_i134_v1`
- Target: Issue #134; compact round table, two separate stools and a modest wall-side privacy divider.
- Generated with Codex built-in ImageGen on 2026-10-31. `source_original.png` is byte-preserved; model version was not exposed.
- Content QA: PASS for the requested furniture set: one round table, exactly two individual stools, and one divider. No people or extra service equipment are baked in.
- Framing: PASS for basic silhouette bounds; thresholded alpha bbox is x=291..1232, y=46..969 in a 1536×1024 image, with 46px top and 54px bottom margin. No nonzero alpha touches the canvas edges.
- Alpha QA: FAIL under the strict opaque-sprite gate. Alpha max is 254; there are zero fully opaque pixels and 467,587 pixels at alpha 128–254. See the white-matte preview; it is diagnostic only.
- Projection QA: FAIL for calibrated `iso2x_v1`; this is an uncalibrated three-quarter illustration. No orthographic control points or Godot overlay.
- Dimensions, footprint, anchor, chair pull-out clearance, access and in-game display scale: NOT CHECKED.
- Review-only asset; no seating behavior or runtime logic is implied. `runtime_approved:false`.

`qa_preview_white.jpg` is a white-matte diagnostic composite and does not replace the original.
