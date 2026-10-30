# Wall freezer with frozen food — hero review candidate v1

- Generated using Codex built-in image_gen on 2026-10-30 for open roadmap item **Issue #125 F01 (P0)**.
- Untouched source: `source_original.png`, 1536×1024 PNG, 1747396 bytes, SHA-256 `871d187667eab253eb9585623b76482c136eb25c6ca359071eb2a24881fd9514`.
- Exact prompt:

```text
Create one complete isolated 2D game asset of a Japanese convenience-store wall-mounted upright frozen-food display case for Issue #125 F01. One coherent refrigerated fixture with its frozen foods visible inside the glass doors (goods are part of this baked image, not separate floating cards). Show a customer-facing front with two tall glass doors and one short right side in an approximately 2:1 isometric game view. The doors have simple vertical handles; inside are several clearly visible lit shelves, front-facing colorful frozen-food bags and shallow meal trays, and subtle cool-white LED lighting. Include a compact gray compressor plinth and clean dark-gray frame. Refined polished stylized Japanese convenience-store management game illustration with crisp shapes, readable at game scale, moderately detailed, not photorealistic. True transparent PNG background, opaque case and food pixels, clean silhouette. Keep the entire case in frame and leave at least 12% clear transparent margin on all sides. No room, wall, floor, background, vignette, glow outside the case, text, brands, logos, people, signage, separate objects, detached product cards, thick cuboid packages, watermark, or extra neighboring cases.
```

## Focused QA — FAIL / review only

- Content matches the requested upright wall freezer: two glass doors, vertical handles, cool-white shelf lighting, multiple shelves, and frozen food visible inside.
- Alpha counts: 977,158 alpha 0; 8,414 alpha 1–127; 587,292 alpha 128–254; zero alpha 255. Nonzero alpha reaches the bottom image edge. The light-matte preview is not the original image.
- Alpha>=128 bounds are `[371,91,1165,967]`; margins L/R/T/B 24.15/24.09/8.89/5.47%. The weak-alpha fringe reaches the bottom edge.
- The case has a near-front perspective and visible depth, but it is not calibrated to iso2x_v1 control points. Dimensions, footprint, ground anchor, four rotations, and Godot display are unverified.
- This is one hero image, not the full three-view design set. Original was not cropped, resized, repainted, or alpha repaired.
- Decision: **FAIL** for runtime acceptance. Keep `runtime_approved:false`.
