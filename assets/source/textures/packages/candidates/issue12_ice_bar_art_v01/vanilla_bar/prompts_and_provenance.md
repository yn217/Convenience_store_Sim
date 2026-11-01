# Prompts and provenance — `ice_bar_pack` vanilla bar

- Created: 2026-10-24
- Tool: built-in Codex ImageGen (no external image API or user-provided image input)
- Model/version identifier: not exposed by the built-in tool; not inferred.
- Intended source asset: flat front print artwork for UV mapping onto a Blender wrapper mesh.
- Physical dimensions from project SKU contract: 0.080 × 0.025 × 0.175 m (W × D × H).
- Generated files: `front_art_a.png`, `front_art_b.png` (each 1024 × 1536 RGB PNG).
- SHA-256: A `bde9f7e830b72787a0c17ee903ab9b2a4887bdc9081b4a7aedfb57a710c4bca8`; B `4c3ae6848e3235007643ccf86e8632c78dcbd38a000b8824ef838826fab17c6b`.
- Rights status: generated candidates; commercial-use terms and redistribution permission have **not** been reviewed. Pending #29/license review.
- Runtime status: `runtime_approved: false` for both files. No mesh UV validation, four-direction render, in-game display, or visual QA at runtime has been performed.
- Human visual check: both saved PNGs were opened and inspected. They show distinct flat portrait artwork and vanilla-bar food illustration; no obvious letters, logos, barcodes, or store background were observed. This is not legal clearance.

## Prompt A — `front_art_a.png`

```text
Use case: product-mockup. Asset type: flat front-face packaging artwork for UV mapping onto a long narrow rectangular individually wrapped vanilla ice bar; not a 3D packshot.
Create concept A for a premium Japanese convenience-store frozen dessert: enticing creamy vanilla ice bar with subtle bean flecks, restrained vanilla flower/pod illustration. Full-bleed portrait 2:3 canvas, 1024x1536, straight-on flat graphic, upright, intended for wrapper mesh dimensions 0.080 x 0.025 x 0.175 m. Distinct refined layout: warm ivory and vanilla-cream ground, muted deep teal framing/graphic blocks, tiny warm gold accent, centered hero food illustration with ample uncluttered negative space and delicate editorial botanical accents. Realistic high-end food illustration and believable premium matte retail print, appetizing soft cream highlights, but the canvas itself is flat printed design, not photographed packaging. No folds, seams, perspective, cast shadow, background scene, hands, or other objects.
Absolutely no text of any kind: no letters, words, numbers, glyphs, pseudo-writing, logos, symbols resembling writing, barcode, QR, nutrition panel, watermark, brand or copied trade dress. Flat front art only.
```

## Prompt B — `front_art_b.png`

```text
Use case: product-mockup
Asset type: flat front-face packaging artwork / UV color texture for a long, narrow rectangular individually wrapped vanilla ice cream bar; not a 3D object or product photograph.
Primary request: concept B, clearly different from concept A: a premium Japanese convenience-store frozen dessert wrapper print design with a delicious creamy vanilla ice bar illustration, vanilla-bean flecks and a small botanical vanilla pod/flower accent. The package dimensions are 0.080 × 0.025 × 0.175 m; the full artwork is intended to map onto the slim front face of that wrapper mesh.
Scene/backdrop: canvas itself is a full-bleed flat printed wrapper graphic, no photographed scene.
Style/medium: refined realistic food illustration, high-quality Japanese retail packaging design, understated elegant matte print.
Composition/framing: portrait 2:3, 1024×1536, straight-on orthographic graphic plane, upright for direct UV mapping. Use a bold asymmetrical diagonal composition with deep midnight navy field, pale lavender-blue band and clean white/ivory central area, cool silver accents; hero ice bar illustration dominates one zone, botanical detail is restrained. This layout and palette must visibly differ from an ivory/teal/gold centered design. Full-bleed artwork only, no wrapper mockup, no folds, no shadow, no perspective.
Lighting/mood: cool, clean, premium freezer-dessert mood, appetizing soft highlights in the food illustration.
Materials/textures: subtle creamy ice texture, fine vanilla specks, crisp but natural food illustration, matte printed-film aesthetic.
Text (verbatim): none.
Constraints: absolutely no letters, words, numerals, punctuation, glyphs, pseudo-text, logos, brand marks, barcode, QR, nutrition labels, writing-like symbols or watermark.
Avoid: any 3D package object, store background, people, extra products, fake text, recognizable brands/trade dress.
```
