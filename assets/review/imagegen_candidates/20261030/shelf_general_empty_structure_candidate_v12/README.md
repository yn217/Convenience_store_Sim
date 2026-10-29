# shelf_general EMPTY candidate v12

Review-only Codex ImageGen output. Original RGBA PNG is preserved byte-for-byte. The v10 `projection_guide.png` and user game screenshot were supplied as image references (geometry and style respectively).

## QA summary

- Four distinct usable shelf boards are visible above the dark base; single-sided, EMPTY and roofless structure are recognizable.
- Long-axis direction now slopes downward toward image-right, consistent in sign with the guide. Manual image-space estimate from the top board's straight edges is about +0.36 to +0.40 rather than the target +0.50. The depth vector is about −0.51, but projected depth/long length is only about 0.29 versus 0.47917. Perspective/foreshortening and shallow depth remain visible; these are approximate visual landmark estimates, not a calibrated control-point measurement. Overall projection FAIL.
- Alpha >127 bounds are [275,145,952,1156] on a 1254×1254 canvas: top margin 11.6%, bottom 7.8%, so the requested 12% safe margin fails. Alpha=1 reaches the bottom border; no strong opaque pixels touch any border.
- Godot display scale, anchor, footprint registration, and runtime are not tested. Keep `runtime_approved:false`. Do not crop or stretch the original to hide projection error.

## Exact prompt used

```text
Generate a NEW single transparent 2D game sprite image for shelf_general EMPTY, version v12. This is a standalone image-generation request, not a review. Use the attached projection guide as a direct strict reference for geometry and camera: match its axes, outline, and axonometric orthographic view. Use the attached game screenshot only for soft warm miniature-game rendering style; do not copy its scene.

Critical iso projection directions in image coordinates (x increases right, y increases down):
- The long shelf axis is (+540,+270): from the image-left end to the image-right end, the shelf front lip MUST slope DOWN to the right at dy/dx=+0.5. It must never slope up to the right.
- The depth axis is (+258.75,-129.375): toward the back, x increases right while y goes UP, slope -0.5.
- Projected depth/long edge length ratio exactly 0.47917.
- This is an axonometric orthographic 2D game view, no perspective convergence or foreshortening.
- footprint 1×2 tiles; fixture dimensions 0.92 × 1.92 × 1.50m; access edge E.
- FOUR clearly separate thin usable product shelves above a separate charcoal kick plate. Visible gaps between all boards; the lowest shelf is above the plinth and is not the plinth top. Exactly four product shelf boards.
- Slim end posts, one central perforated backboard, single-sided, roofless, no canopy or top cap.

Composition / alpha:
- Whole fixture isolated and centered, object bounds within central 70% of both canvas dimensions to preserve at least 15% transparent margin around all edges.
- Truly transparent RGBA, zero alpha at all four borders and no halo or cast shadow.
- Matte cream/warm-white painted steel, charcoal base, soft hand-painted game shading. No glossy metal.
- No products, floor, labels, text, diagram labels, extra props, alternate views, crop, frame, boxes, strong outlines or ambient occlusion.
```
