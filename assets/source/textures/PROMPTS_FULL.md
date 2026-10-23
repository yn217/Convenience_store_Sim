# Full generation prompts

These are the prompts used for the six source comparison boards in PR #65.
The built-in image generation tool did not expose a model name/version or
seed; those fields remain explicitly unavailable in the provenance JSON.

## `sku_onigiri_comparison_v01.png`

```text
Use case: product-mockup
Asset type: game texture source for a fictional Japanese convenience-store simulator
Primary request: create a clean square comparison board containing two distinct fictional onigiri package label concepts side by side, clearly labeled only with generic invented marks (no real brands, no readable Japanese text, no logos), one warm coral-and-cream triangular rice-ball package and one teal-and-yellow triangular rice-ball package. Flat front-facing package artwork, high legibility at tiny sprite scale, simple geometric rice/grain motif, no product photography, no watermark.
Style/medium: polished 2.5D game texture reference, crisp vector-like painted raster
Composition/framing: two equal panels with generous margins, front view, neutral light background
Lighting/mood: soft even studio light
Color palette: coral, cream, teal, yellow, charcoal accents
Materials/textures: matte plastic wrapper, subtle paper grain
Constraints: fictional packaging only; no real trademarks, no copied brand design, no claims of final four-direction sprite
Avoid: photorealistic hands, shelves, perspective distortion, tiny illegible paragraphs, brand names, watermark
```

## `sku_tea_comparison_v01.png`

```text
Use case: product-mockup
Asset type: game texture source for a fictional Japanese convenience-store simulator
Primary request: create a clean square comparison board with two distinct fictional bottled tea package label concepts side by side, using invented abstract marks only, no real brands, no readable Japanese text, no logos. One amber tea bottle label uses deep green and cream with a leaf-and-wave motif; the other uses plum purple and pale gold with a geometric tea-leaf motif. Front-facing flat label artwork, high contrast at tiny sprite scale, no product photography, no watermark.
Style/medium: polished 2.5D game texture reference, crisp vector-like painted raster
Composition/framing: two equal panels with margins, front view, neutral background
Lighting/mood: soft even studio light
Color palette: deep green, cream, amber, plum, pale gold, charcoal
Materials/textures: matte coated paper label, subtle fibers
Constraints: fictional packaging only; no real trademarks, no copied brand design, no claims of final four-direction sprite
Avoid: shelves, perspective distortion, illegible paragraphs, brand names, watermark
```

## `sku_cupnoodle_comparison_v01.png`

```text
Use case: product-mockup
Asset type: game texture source for a fictional Japanese convenience-store simulator
Primary request: create a clean square comparison board containing two distinct fictional cup-noodle package label concepts side by side, clearly labeled only with generic invented marks (no real brands, no readable Japanese text, no logos). One warm orange-and-cream cup package uses an abstract noodle swirl and simple grain motif; the other uses deep blue and lime with a geometric steam motif. Flat front-facing package artwork, high legibility at tiny sprite scale, simple shapes, no product photography, no watermark.
Style/medium: polished 2.5D game texture reference, crisp vector-like painted raster
Composition/framing: two equal panels with generous margins, front view, neutral light background
Lighting/mood: soft even studio light
Color palette: orange, cream, deep blue, lime, charcoal accents
Materials/textures: matte coated paper sleeve, subtle paper grain
Constraints: fictional packaging only; no real trademarks, no copied brand design, no claims of final four-direction sprite
Avoid: photorealistic hands, shelves, perspective distortion, tiny illegible paragraphs, brand names, watermark
```

## Fixture material boards

The three fixture boards used the same structure: a square two-panel,
front-facing orthographic material study with no products, readable text,
logos, people, or store scene; polished realistic 2.5D game texture source;
soft studio light; generic fictional material study; not a final sprite.

- `register_basic_material_comparison_v01.png`: brushed stainless counter with graphite polymer trim versus warm light-gray powder-coated metal with charcoal trim and blank paper POP holder.
- `shelf_general_material_comparison_v01.png`: cool white powder-coated steel with gray shelf lips versus pale warm laminate with light wood grain and matte charcoal uprights.
- `fridge_drink_material_comparison_v01.png`: cool white painted metal frame with clear glass and cyan LED versus pale gray aluminum frame with warmer neutral LED and transparent glass.

## Review status

These prompts intentionally prohibit real brands and readable copied text, but
human visual review is still required before runtime adoption. The source
boards and crops are staging assets only.
