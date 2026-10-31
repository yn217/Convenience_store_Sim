# shelf_general FULL/r0 — integrated candidate v6

Review-only ImageGen output. The unmodified source is `source_original.png` (1402×1122 RGBA, SHA-256 `9166f5a4fd0409ecf91a59835017b1fc8ecd7d5d904299a29acf6584c89eff92`). No crop, manual repaint, or geometric transform was applied. `comparison.png` places the EMPTY reference, v5 and v6 on a common neutral background. The exact generation prompt and reference roles are in `prompt_record.txt`.

The image shows four stocked rows in one integrated shelf-plus-merchandise sprite. This is still a rejected review candidate: alpha>8 leaves only 4.90% bottom margin and low-alpha pixels touch the bottom edge; the broad blank plinth remains conspicuous. Hough line sampling detects long board edges near +0.5, consistent with the guide's long-axis sign, but the depth-axis assignment, 0.47917 depth/length ratio, E/+X access mapping, ground anchor, contact and Godot display were not verified. Do not crop/stretch the source to mask these failures.

`runtime_approved:false`; no runtime/Renderer changes.
