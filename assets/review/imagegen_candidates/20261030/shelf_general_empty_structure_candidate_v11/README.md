# shelf_general EMPTY candidate v11

Review-only output from Codex built-in ImageGen. The raw 1536×1024 RGBA PNG is preserved unchanged. No input image was attached to the final generation call; geometry was specified in text and checked afterward against v10's iso2x_v1 guide.

## Independent visual QA

- Four distinct usable shelf boards are visible above a separate dark plinth.
- The fixture reads as an empty, single-sided open gondola; no canopy or roof is present.
- **FAIL:** the shelf long edges rise toward image-right (approx. slope −0.23 on the prominent front lip) while the guide specifies +0.5 for the long projected vector. The image uses converging perspective-like edges, so its projected directions and 0.47917 depth/long ratio do not match the game contract.
- **FAIL:** alpha extends to x=0 at a very low value and the top/bottom margins are below the requested 12%; edge safety is not met.
- Soft style is closer to the target, but broad pale shelf surfaces and shadow-like translucent dark halo remain visible in the RGBA image.
- No Godot screenshot, game-scale, anchor, footprint fit, or runtime test was performed. Keep `runtime_approved:false`.

## Exact generation prompt

```text
Create one review-only raster game asset: EMPTY single-sided open gondola shelf for a Japanese convenience-store management game. Isolated, centered full fixture, one three-quarter isometric view, true transparent background and minimum 12% fully transparent margin on all four edges. Warm soft miniature-game illustration, matte warm-white painted steel, restrained charcoal kick plate, gentle diffuse shading.
Strict geometry: iso2x_v1, world footprint 1x2 tiles, fixture 0.92m wide × 1.92m long × 1.50m tall, customer access edge E. Long projected vector (540,270), depth vector (258.75,-129.375), depth/long ratio 0.47917; edge slopes +0.5 and -0.5. Follow the square attached geometry reference if available; preserve its camera, edge directions and proportions.
Show exactly FOUR thin usable shelf boards with clearly visible vertical gaps. Count four boards above a separate low dark kick plate; the base top does not count as a shelf. The bottom board must be visibly distinct from the plinth. Show four front lips and shallow shelf surfaces. Include slim end uprights and a perforated center back panel extending behind shelves. Open top with no roof, canopy or cap.
EMPTY: no products. No labels, signs, floor, cast shadow, glow, text, border, diagram, extra props, alternate views, crop or frame. Avoid perspective convergence, exaggerated shelf depth, glossy metal glare, thick black outlines and strong AO. Every outer canvas margin remains fully transparent.
```
