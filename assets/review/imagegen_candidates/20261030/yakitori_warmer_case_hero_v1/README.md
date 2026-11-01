# Yakitori warmer case — hero review candidate v1

- Codex built-in imagegen output for Issue #125 C04 (P1), generated 2026-10-30.
- Original preserved unchanged: `source_original.png`, 1536×1024 PNG RGB, 2345364 bytes, SHA-256 `f225514e54a65f20b2df617252d669e6556a653f22d5070dbdacc98fa853c04d`.
- Exact prompt used:

```text
Use case: Japanese convenience-store interior game asset. Asset type: one isolated review candidate image for Issue #125 C04 yakitori/skewer warmer showcase, no words or brand text. Primary request: create a single complete compact counter-side heated display case with its grilled skewers as one coherent baked 2D illustration; the skewers must sit naturally inside the case, not float as separate cards. Subject: a low rectangular stainless-steel warming case with clear glass panels, a short dark base, one shallow row of yakitori skewers laid horizontally on a warming tray, visible wooden skewer ends, restrained warm interior light, a narrow front price rail with blank tags. Style/medium: polished, clean, stylized Japanese convenience-store management game art, crisp readable shapes, restrained realistic detail, not photorealistic. Composition: one complete fixture centered, customer-facing front and short right side visible, approximately 2:1 isometric game projection with clean consistent axes, whole case in frame and at least 12% transparent margin on every side. Background: true transparent PNG. Constraints: opaque case and food, clean silhouette, no room, wall, floor, backdrop, cast shadow outside object, people, extra appliances, separate props, detached product cards, thick cuboid skewers, text, logos, watermark, or neighboring fixtures.
```

## Focused QA — FAIL / review only

- One compact heated showcase with glass panels, a warming tray, and grilled yakitori skewers integrated in the case is visually identifiable.
- The image is RGB with a checkerboard visibly baked into the pixels; it has no alpha channel and is not a transparent game sprite.
- The case nearly fills the image and does not leave the requested 12% clear margin on every side. Its view is perspective and has not been calibrated to `iso2x_v1`.
- Dimensions, footprint, ground anchor, alternate views, and Godot display size are not checked.
- No cleanup or repainting was applied to the source. Do not use at runtime. `runtime_approved:false`.
