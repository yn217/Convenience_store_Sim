# shelf_general EMPTY styled candidate v13

Codex built-in ImageGen edit. First reference: strict v10 projection/geometry guide. Second reference: game art style only. The 1254×1254 RGBA output was copied byte-for-byte from the generated file; no crop, padding, resizing, or repaint was applied.

## Independent QA

- Four usable shelf boards and a separate dark base remain visible; the EMPTY/single-sided/roofless fixture reads clearly.
- After uniformly fitting the guide canvas to 1254×1254 for comparison, alpha silhouette IoU is 0.9805 at threshold >127 (0.9796 at >8). The thresholded bounding boxes differ by at most about 11px. This supports strong silhouette preservation, but is not a substitute for edge-vector/control-point verification.
- The materials are closer to the soft warm game style. Source-level game-size readability and Japanese real-store fixture review remain open.
- Alpha >127 bounds: [161,147,820,1082] on 1254×1254. The top margin is 11.7%, just below the required 12%; alpha=1 reaches the left and bottom borders. Keep the original intact and treat the strict alpha gate as FAIL.
- No Godot anchor, footprint placement, game display, or runtime check has been done. `runtime_approved:false`.

## Exact prompt

```text
Edit the first referenced image into one polished review sprite. The first image is the edit target and strict geometry authority: a precisely constructed empty single-sided gondola. Preserve its full silhouette and every fixture part’s position, orientation, proportion, overlap, and edge direction exactly: four shelf boards, their front lips and depth, slim uprights, central back panel, separate dark base. Preserve the same transparent canvas, composition, proportions and anchor. Do not rotate, perspective-warp, crop, resize, add/remove/move parts, or change shelf count. Do not reinterpret geometry. Only change rendering/material finish to a warm, softly shaded miniature-game illustration inspired by the second reference image. Matte warm-white/cream painted steel, restrained charcoal base, gentle diffuse shading. No photoreal gloss. One isolated EMPTY shelf, transparent RGBA. No products, signs, labels, text, floor, shadow, glow, border, frame, diagrams, added accessories, roof/canopy or alternate views. Keep all outer alpha and geometry alignment faithful to the first image.
```
