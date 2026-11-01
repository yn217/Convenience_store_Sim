# Provenance and validation — Issue #61 / #22 shelf surface candidates

## Generation record

- Generator: Codex built-in ImageGen.
- Date: 2026-10-24 (Asia/Tokyo task date).
- Generation mode: two separate text-to-image generations; no reference image.
- Intended content: flat, front-facing, evenly lit material-color candidates only.
- Initial output: each PNG was 1254×1254 pixels, RGB.
- Repository output: each image was resized to 1024×1024 with Pillow Lanczos and saved as RGB PNG. No alpha channel, fixture geometry, or runtime code was added.
- `PREVIEW.png`: RGB, 1480×1880; shows each candidate repeated 3×3 at 256 px per tile and enlarged 64 px strips from each opposing edge.

## Repository output hashes (SHA-256)

- `powdercoat_white_a.png`: `84081F5BCDE86D4215894B90096B8480A18E7F5D54C66AEF27EC6D3036DCE012`
- `resin_lightgray_b.png`: `C24D19A9F8B5D2D7F65D39AAC04670AC010EBF71F1FC4813D046A78772166671`
- `PREVIEW.png`: `EAC71E3405445CDD76CF215EDFFDA5B2C3924190CEFF587FE378245C892A8AC3`

## Exact prompts

### A — `powdercoat_white_a.png`

```text
Use case: stylized-concept. Asset type: albedo/base-color only texture candidate for clean Japanese convenience-store shelving. Primary request: one square texture of a flat, uniform satin white powder-coated steel surface. Neutral clean white, subtle fine powder-coat microtexture, very low contrast. Composition: perfectly front-facing orthographic plane filling the full canvas, even detail distribution. Lighting: neutral diffuse studio illumination, completely even, no directional highlights, no shadows or gradients. Materials: satin powder-coated steel shown as albedo color only, no metallic shine or reflections; subtle fine grain, minimize low-frequency variation to reduce visible repetition in 3x3 UV preview, but do not imply seamlessness. Constraints: texture surface only, not a PBR map. Absolutely no shelving shape, borders, edges, grooves, seams, rails, labels, products, background, text, logo, watermark, streaks, scratches, dents, dirt, embossed features, vignette or cast shadow.
```

### B — `resin_lightgray_b.png`

```text
Use case: stylized-concept. Asset type: albedo/base-color game texture candidate for clean Japanese convenience-store fixtures. Primary request: one square 1024x1024 texture, a flat light gray durable ABS/plastic surface, slightly gray compared with white, with a very subtle fine stippled matte grain. Composition: front-facing orthographic planar surface filling the canvas, uniform detail. Lighting: neutral diffuse and evenly distributed, no directional lighting, highlight streaks, shadows, gradients, or vignette. Material: light gray durable ABS/resin, albedo appearance only, fine subtle microtexture, low-frequency variation minimized to make 3x3 UV tiling unobtrusive without claiming seamless. Constraints: texture only, not a PBR map. Absolutely no object shape, fixture edges, grooves, seams, label rails, products, background, text, logos, watermark, scratches, dirt, swirls, embossing, borders, reflections, hard highlights.
```

## Edge / repeat review

Reviewed visually in `PREVIEW.png` after normalization to 1024×1024. The 3×3 views show a faint repeated boundary for both candidates; A has the more apparent horizontal join. Therefore these outputs are **not seamless-certified**. They remain useful as visual material candidates, but obvious tiling may occur on broad exposed UV islands.

For an additional simple edge check, mean absolute RGB difference (0–255 scale) between opposing boundary pixels was compared with the mean absolute difference between ordinary adjacent texels:

| Candidate | left ↔ right edge | top ↔ bottom edge | ordinary adjacent X / Y |
| --- | ---: | ---: | ---: |
| A — powder coat | 7.11 | 10.07 | 7.10 / 8.78 |
| B — light gray resin | 6.27 | 6.91 | 6.14 / 7.80 |

This metric is a screening aid, not proof of seamlessness or perceptual acceptance. The visual preview is authoritative for the noted faint seam observation.

## Not yet verified / approvals

- Physical material behavior, real-world color matching, PBR metallic/roughness values, normal/height maps: **not verified**.
- UV scale, seams on actual fixture meshes, mipmapping/filtering, lighting response, and Godot/runtime appearance: **not verified**.
- Commercial-use/license review: **pending**; do not treat as approved for release until reviewed under the project's asset-rights process.
- `runtime_approved: false`.
