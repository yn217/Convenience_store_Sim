# Gondola edited FULL candidate v1

- Producer: Codex built-in ImageGen direct edit, 2026-10-30.
- Source: `gondola_edit_v1.png`, 1254×1254 RGBA, 1,421,416 bytes, SHA-256 `ecaf3dff3b2d2c927ecce3e9337649d2423ef14475d628ce232097439025be07`. Source image retained byte-for-byte.
- Image 1: empty shelf v13 geometry/camera authority. Image 2: game art style only.
- Exact prompt is recorded below. Transparent background and >=15% margins were requested.
- The direct edit broadly resembles the empty guide, but its whole-image alpha bounds are about 15% larger in both width and height. Goods obscure the fixture-only silhouette and spill onto the plinth, so exact geometry is not preserved/verified.

## Focused QA: FAIL

- Integrated shelf+goods image; fronts are readable.
- Alpha>127 bbox `[166, 83, 929, 1161]`; L/R/T/B margins 13.24% / 25.92% / 6.62% / 7.42%; 12% minimum fails at left/top/bottom.
- Products have visible sides/volume. The dark plinth/base is stocked, contrary to the fixture specification.
- Untransformed whole-alpha-mask IoU against empty v13 is 0.70670; product pixels are included, so this is not a fixture-only shape score. The alpha bounding box is about +15.78% in width and +15.29% in height versus the empty guide.
- Comparison is side-by-side on each original 1254×1254 canvas without crop/resize. This is not landmark calibration. Footprint anchor and Godot runtime are not checked.
- Review only; `runtime_approved:false`; no game or runtime files modified.

## Prompt

Use case: stylized-concept. Asset type: review-only integrated game sprite for a Japanese convenience-store gondola shelf. Edit Image 1 only; it is the exact empty fixture and geometry/camera authority. Preserve its full silhouette, shelf count, shelf edges, back panel, uprights, base, camera, projection, position and scale exactly. Only add fictional snack and bread packages as a dense FULL inventory placed directly on the four existing selling surfaces. Package fronts should face the camera and be nearly flat with almost no visible top/side thickness. Do not change, remove, extend, tilt, thicken or add fixture parts. No roof, canopy, header, extra shelf rows, detached/floating cards, cuboid products, floor, glow, readable text, logos, or brands. Image 2 is style reference only: hand-painted isometric game illustration; do not copy the scene. Transparent background; keep at least 15% clear margin on each side. The shelf and goods form one integrated review image. Keep source geometry and alpha as close as possible.
