# shelf_general EMPTY structure candidate v6

- Status: review candidate only; `runtime_approved: false`
- Scope: single-sided, empty gondola structure. No products and no runtime integration.
- Generation: Codex built-in ImageGen, guided by `projection_guide.png` and the game-style reference `image-1792819026698.webp`.
- Source image: `shelf_general_empty_structure_candidate_v6.png` (original bytes copied without resizing or editing).
- SHA-256: `C010CD4230953AF626727DB84F22B6EC784F3B9A01DB8BC0B5B58DCF9B59BAEC`
- Canvas: 1312 × 1199 RGBA.
- Alpha: true transparency; alpha range 0–255 with 256 levels. Any-alpha bounding box `(0, 37)–(1286, 1199)` touches left and bottom canvas edges. Alpha >127 bounding box `(313, 142)–(1035, 1174)` leaves 25 px at bottom. Alpha edge leakage is a FAIL for sprite-margin QA.
- Preliminary visual QA: four shelf planes and perforated back panel are present; no products or roof/canopy. The long shelf edges appear close to the intended down-right isometric direction. Shelf depth looks reduced from v5, but the dark base still appears too tall/heavy. Pixel-to-world dimensions and Godot display scale have not been verified.
- Independent review: pending at initial commit; results will be appended without changing the generated image.

## Prompt

Create one high-quality finished 2D game sprite by adding restrained painted material detail to the exact geometry in reference 1. Preserve the guide's silhouette, four shelf planes, spacing, short depth vector, narrow base, edge directions, and camera exactly; do not reinterpret or enlarge any shelf. It is a Japanese convenience-store single-sided EMPTY gondola: 4 very shallow narrow ledge shelves, thin front lips, a vertical perforated back panel directly behind, two slim end posts, and a low thin kick plate. No roof, canopy, cap, or additional shelf. Do not add products. The guide is dimensionless but depicts the long dimension much greater than shelf depth; each shelf's top surface must remain a narrow band, with front-to-back projected depth no more than 12% of its long projected run. Base fascia height must be under 4% of total shelf height. No roof/canopy/top cap. Exact iso2x_v1 axes from guide: all long shelf edges run screen-right-down with vertical/horizontal slope 0.5; depth edges run screen-right-up with slope -0.5; uprights vertical. Never change viewpoint, perspective, or aspect ratio. Use the second reference only for its warm polished hand-painted miniature game style, not its scene. Matte warm-white painted steel, fine small perforations, charcoal narrow base, soft controlled shading and crisp silhouette; no shiny photoreal chrome. True transparent RGBA background with at least 15% empty margin on all four sides. No low-alpha pixels may touch any canvas edge. Do not draw checkerboard, glow, halo, floor/shadow, text, label, logo, callout, border, collage, extra view, or prop.

## Independent review (GPT-6 Luna subagent)

Overall: **FAIL**. The candidate is a recognizable single-sided gondola with four shelves and no products or roof. Long-axis projection is close to the requested down-right +0.5 direction. However, projected shelf depth is only about 1/7–1/9 of the long run, much shallower than the approximately 1/3–1/4 target. The guide itself encoded about 1/8, so this failure originates in the guide rather than a successful match to the target. Low-alpha pixels touch the left and bottom edges. The metallic highlights and heavy dark base also miss the softer game style. Do not resize/crop this into approval; correct the projection guide and regenerate.
