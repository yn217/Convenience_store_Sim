# shelf_general FULL dense v2 — ImageGen review candidate

- Asset ID: `shelf_general_open_r0_full_dense_v2`
- Scope: one FULL integrated shelf-and-products review sprite; no runtime use.
- Generated with Codex built-in ImageGen on 2026-10-31. `source_original.png` is the untouched tool output.
- Content inspection: complete one-sided gondola and four product-bearing levels; packages are integrated behind the rails and fronts face the access side. The render still shows substantial white shelf/backboard area and the upper panel reads broad; this is a review candidate, not a pass.
- Alpha/projection/geometry metrics are recorded in `QA.json`. Projection is not calibrated to `iso2x_v1`; footprint, anchor and Godot display remain unchecked.
- `runtime_approved:false`.

- Alpha QA: FAIL. Source is 1254×1254 RGBA. 52 pixels at the left canvas border have alpha 1; partial alpha also covers most visible subject pixels. Source was preserved unchanged.
- Framing: FAIL because faint nonzero alpha touches the canvas edge, although the alpha≥128 silhouette itself is contained.
- Visual focused QA: four stocked levels and front-facing packaging are legible at full resolution; the upper backboard and several pale shelf areas remain broad. Not independently reviewed.
