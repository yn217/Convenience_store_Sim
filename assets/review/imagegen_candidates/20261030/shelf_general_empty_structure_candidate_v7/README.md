# shelf_general EMPTY structure candidate v7

- Review-only; `runtime_approved: false`.
- Generated with Codex built-in ImageGen from a custom iso2x projection guide and the game-style reference `image-1792819026698.webp`.
- The source image was copied byte-for-byte from the ImageGen output; it was not cropped, resized, repainted, or cleaned.
- Original: `shelf_general_empty_structure_candidate_v7.png`
- Canvas: 1254 × 1254 RGBA. SHA-256: `0b614a1336de495c3e9960e8bf5496a9d12daa984593fdca3325230627625bd2`.
- Guide projection: long vector `(500, 250)` and depth vector `(170, -85)`. Projected length ratio `190.07 / 559.02 = 0.34`; both axes use ±0.5 screen slope.
- Preliminary visual QA: the generated image visibly has only three shelf planes, not the four in the guide. The base is visually too tall. Object edge directions look approximately isometric but generated depth appears below the guide target. No products or roof are visible.
- Alpha QA: true RGBA, range 0–255, 256 distinct alpha values. Nonzero alpha bbox `(0, 25)–(1226, 1254)` touches left and bottom edges; alpha >127 bbox `(249, 67)–(1020, 1214)` leaves 40 px at bottom. Edge contact is a FAIL.
- Comparison: `comparison_guide_v7.png` shows the guide and generated output at preserved aspect ratio.
- Independent visual review is pending at time of initial record. No runtime, Godot-size, or anchor verification has been performed.

## ImageGen prompt

Create a polished, single-sided Japanese convenience-store EMPTY gondola sprite by faithfully coloring reference image 1. Treat its geometry and camera as a locked orthographic construction drawing: preserve the exact four shelf planes, vertical spacing, full silhouette, very narrow low base, two end posts, back panel, and every edge direction. The shelf planes must retain the guide's projected depth-to-long-axis ratio of about 0.34 (approximately 1:3); do not make them shallower or deeper. Long edges slope screen-right-down at +0.5; depth edges slope screen-right-up at -0.5; verticals remain vertical. There are exactly four usable shelves. No extra top shelf, roof, canopy, header or cap. No products. Keep base fascia under 4% of the back-panel vertical height. Add only restrained, soft hand-painted miniature-game shading matching the style reference, with matte warm off-white painted steel, quiet charcoal accents, fine subtle perforations, soft ambient occlusion and crisp silhouette. Avoid photorealistic chrome, strong black outlines, bloom, or dramatic shadows. True transparent RGBA background with generous clear margin at all sides, at least 12%; no nonzero or low-alpha pixels may touch the canvas boundary. No checkerboard, floor, cast shadow, halo, text, labels, logo, callouts, border, collage, extra view, or props. Output just one isolated complete gondola fixture on transparent background.

## Independent visual review (GPT-6 Luna subagent)

Overall: **FAIL**. The reviewer also sees only three usable shelves rather than four, finds the depth visually too shallow despite broadly correct axis directions, and flags the hard glossy finish. The fixture type is recognizable and roofless; the base fascia looked low to the reviewer. The reviewer did not visually detect alpha edge contact, but the measured alpha mask contradicts that visual impression: nonzero pixels reach the left and bottom canvas boundaries. Pixel measurement is retained as the alpha QA result.
