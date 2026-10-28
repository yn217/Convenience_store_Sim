# Provenance — Issue #61 floor porcelain candidates

- Generation date: 2026-10-24 (Asia/Tokyo)
- Generator: Codex built-in ImageGen
- Final files: 1024×1024 RGB PNGs. Built-in ImageGen returned 1254×1254 RGB squares; normalized with Pillow LANCZOS. No alpha, perspective warp, or color grade was applied.
- Physical scale: not confirmed; conceptually one image is 1 m × 1 m with four subtiles. Actual UV density is unverified.
- UV mapping / Blender application / Godot display: not checked.
- `runtime_approved: false` for both candidates.
- Commercial-use / license review: pending; review applicable terms before redistribution or commercial adoption.
- No brands, labels, text, props, or scene elements were requested.

## Exact prompts

### A — initial generation

```text
Use case: stylized-concept. Asset: square albedo candidate for a Japanese convenience-store game floor. Create a 1024×1024 square, perfectly top-down orthographic image of a flat 1 m × 1 m surface divided into a restrained 2×2 grid of bright warm off-white glossy porcelain tiles by thin, subtle low-contrast grout. Broad even illumination, smooth ceramic with gentle controlled sheen, no hot reflections. No perspective, no objects, no scene, no outer gradient, no shadows, no text, no logos, no watermark. Tile texture only; does not alter the game's 2:1 isometric tile projection. Do not claim mathematically seamless; keep boundaries visually quiet.
```

### A — refinement edit applied to initial A

```text
Edit this texture only. Preserve the bright warm ivory glossy porcelain, the subtle 2×2 grout layout, and the exact square top-down flat surface. Remove the outer beveled frame, border rim, edge darkening, edge gradient, cast shadow and any lighting falloff. Make the porcelain faces and grout continue cleanly and evenly all the way to all four image edges, with uniform broad illumination and gentle controlled sheen. Keep tile seams thin, quiet and aligned; no perspective, objects, text, logos or watermark. This is a material texture candidate, not a claim of mathematically seamless tiling.
```

### B — initial generation

```text
Use case: stylized-concept. Asset: square albedo candidate for a Japanese convenience-store game floor. Create a 1024×1024 square, perfectly top-down orthographic image of a flat 1 m × 1 m surface divided into a restrained 2×2 grid of slightly warm pale greige porcelain tiles by thin, subtle low-contrast grout. Add delicate natural stone mottling and fine understated mineral grain; matte-leaning finish with a very soft sheen, broad even illumination, no hot reflections. No perspective, no objects, no scene, no outer gradient, no shadows, no text, no logos, no watermark. Tile texture only; does not alter the game's 2:1 isometric tile projection. Do not claim mathematically seamless; keep boundaries visually quiet.
```

## Boundary/repetition review

`PREVIEW.png` was visually inspected as a 3×3 repeat. Measurements compare corresponding RGB pixels on opposite edges; mean/max are absolute channel differences on a 0–255 scale. The 8px-band values compare mean RGB values at the outermost 8px. These metrics cannot certify tiling.

| Candidate | L↔R edge mean/max | T↔B edge mean/max | 8px band mean L/R, T/B | Visual assessment |
|---|---:|---:|---:|---|
| A | 2.02 / 15 | 7.21 / 33 | 2.19 / 6.71 | Exterior rim removed; directional specular band repeats visibly: **non-tileable candidate** pending revision. |
| B | 9.30 / 60 | 9.52 / 53 | 6.44 / 6.87 | No dominant hard join, but stone motifs and edge variation repeat; not certified seamless. |

## SHA-256

- A: `B91178F24041FAEBDAE0C39FA8949E67F51F9418F1414E0243F47BB19DECD41C`
- B: `79BB3CC5539D7EC927A4B3EFDC2F12F9F732637CB4F3D8941977AEC42F2EC0AA`
