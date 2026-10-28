# Mockup bakery product candidates v01

Issue scope: #12 / #61 package art, informed by the user-provided convenience-store mockup.

## Status

Design/source candidates only. `runtime_approved: false`.

These are not `iso2x_v1` sprites: physical dimensions, UV placement, four-direction consistency, shelf contact, anchors, zoom readability, Godot compositing, and licensing review have not been verified. Do not import them into runtime fixtures as-is. The transparent sheet is an early composition proof and is not a production sprite atlas.

## Files

- `bakery_products_sheet.png`: generated visual sheet with melon-pan, curry bun, and cream bun packages; retained for comparison only.
- `melonpan_cutout.png`: isolated package cutout derived by editing the generated sheet.
- `curry_bun.png`: independently generated cutout from an asset-production subagent; copied here after a visual review and alpha-channel check.
- `cream_bun.png`: independently generated cutout from a second asset-production subagent; copied here after visual inspection and alpha check.

## Provenance

- Tool: built-in OpenAI ImageGen (not the API/CLI).
- Reference: user-provided mockup image, used only for general store-art direction; no UI or in-image copy was reproduced.
- Model/version and seed: not exposed by the built-in tool.
- Generation date: 2026-10-24.
- Rights: no third-party art or real brand was intentionally requested. Generated output's licensing and redistribution terms have not been independently reviewed; see Issue #29 before release adoption.
- Human review: visual inspection only; no art-direction approval.

## Prompts

### Initial three-product sheet

> Use case: stylized-concept
> Asset type: candidate game texture source for a Japanese convenience-store bakery display; Image 1 is a visual style/mood reference only and must not be copied as a store screen.
> Primary request: create one clean, transparent-background asset sheet containing exactly three separate, appetizing packaged bakery products that could sit in a glass-front bakery display: a round melon bread in a clear bag with a small pale-green paper band, a golden curry bun in a clear bag with a warm orange band, and a soft cream bun in a clear bag with a pale-yellow band. Keep each product distinct, full object visible, evenly spaced, no overlap.
> Style/medium: premium realistic 2.5D game prop render, physically plausible product photography translated into detailed hand-crafted game art; coherent with a bright, upscale Japanese convenience store interior.
> Composition/framing: three-quarter isometric view from the same fixed direction for all items, consistent camera and soft contact shadows, isolated product cutouts, centered with generous transparent padding; objects are approximately the same physical package scale, with shape-based natural differences.
> Lighting/mood: soft neutral-white overhead retail lighting with gentle highlights on clear packaging; natural warm bread tones.
> Materials/textures: subtle clear wrapper crinkles, believable baked crust, matte paper bands, crisp detailed silhouettes.
> Text: none.
> Constraints: no real brands, no logo, no readable or pseudo-readable lettering, no barcodes, no prices, no tray, no shelf, no background; preserve transparent pixels around the three products. The image is a design candidate, not a calibrated 4-direction or iso2x runtime sprite.

### Melon-pan cutout edit

> Use case: precise-object-edit
> Asset type: one isolated candidate Japanese convenience-store bakery product cutout for a 2.5D game.
> Primary request: From the reference sheet, retain only the leftmost packaged melon bread: a round golden melon-pan in a clear wrapper with the pale sage-green paper band. Remove the other two products completely.
> Input image: generated three-product sheet, used as the edit target and package design reference; preserve selected package shape, wrapper, colors, and camera.
> Style/medium: detailed realistic 2.5D game-prop render matching the source.
> Composition/framing: one whole package centered, three-quarter view unchanged, same apparent physical size as source, with generous transparent margin on every side (at least 12% of canvas), no edge cropping.
> Lighting/mood: preserve soft neutral overhead highlights and subtle grounded shadow.
> Materials/textures: preserve clear crinkled wrapper, baked grid crust, matte sage paper band.
> Text: none.
> Constraints: genuinely transparent background; no other products, shelf, tray, lettering, logos, watermark, or new decorative elements. Do not add pseudo-text.

### Curry-bun cutout

> Create a polished 2D game-asset product cutout: one Japanese convenience-store curry bread bun in a clear glossy flexible plastic wrapper, plump oval golden fried panko crust with realistic uneven amber toasted browning, believable film folds, seams and soft reflections. A plain solid warm orange paper band around the center, completely blank. Three-quarter view, softly dimensional premium isometric convenience-store game illustration style, warm light, crisp readable silhouette. Transparent background with generous margin, entire packaged product inside the frame. No text, letters, pseudo-text, logo, trademark, barcode, price sticker, shelf, background, UI, people, props. One item only.

### Cream-bun cutout

> Create one isolated, photorealistic Japanese convenience-store bakery product cutout: a single round, softly domed cream bun sealed in clear glossy packaging, viewed at a three-quarter angle. A plain pale-yellow paper band wraps the middle, completely blank with no marks. A small natural split in the golden-brown baked top reveals just a little smooth custard. Realistic baked color, delicate bread texture, convincing transparent crinkled film with subtle highlights and seams. Entire product fully inside frame, centered with generous transparent margin, studio product photography, clean silhouette. No real brand, trademark, logo, readable text, pseudo-text, barcode, price label, shelf, UI, people, props, shadow backdrop, or extra objects. Style reference only: the attached convenience-store game mockup's polished, warm, softly rendered product-asset aesthetic; do not reproduce its interface or scene. This is an uncalibrated 2D candidate asset, not an isometric or dimensionally validated production asset.

## Visual review limits

- All three separate images are visually distinct and carry an alpha channel with transparent pixels.
- `curry_bun.png` reaches the right canvas edge at alpha > 16, despite the margin request. Reframe/regenerate it before treating it as a sprite candidate.
- The two other cutouts have margins but their crop/anchor is not shared or calibrated.
- None has verified physical scale, model/UV mapping, four rotations, exact ground contact, zoom checks, Godot compositing, or rights approval.
