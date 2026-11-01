# shelf_general EMPTY projection guide v10

This construction guide uses the current game projection and the canonical `shelf_general` dimensions. It is a guide, not a runtime sprite.

- Game projection source: `scripts/presentation/iso_projection.gd`; each world metre on X and Y has the same projected length. +X is `(64,32)` and +Y is `(-64,32)` at zoom 1.
- Fixture source: `data/fixtures/mvp_v1.json`; footprint `1×2`, dimensions `0.92×1.92×1.50m`, access edge E.
- Long/depth ratio: `0.92/1.92 = 0.47917`.
- Guide vectors: long `(540,270)` and depth `(258.75,-129.375)`, slopes +0.5 and −0.5, ratio 0.47917.
- Four distinct product shelves above a separate low base; board lower vertices use positive image-Y and remain in canvas.
- Guide alpha bounds and SHA are recorded in `guide_QA.json`.
- Anchor, final world scale, Godot display size, and runtime approval are not established by this guide.

## Generated review candidate

- Original ImageGen output: `shelf_general_empty_structure_candidate_v10.png` (kept byte-for-byte; no crop, resize, or repaint).
- Generator: GPT-6 Luna subagent; source SHA-256: `c1e22b01f9359e8f2ab0bcfea836a40f4d227b748e6bc277adda36d29389b1d0`.
- Full prompt used:

```text
Create exactly one EMPTY single-sided convenience store gondola game sprite by rendering reference 1 faithfully. Reference 1 is strict geometry and camera authority: preserve exact silhouette, aspect ratio, edge directions, placements, no redesign. iso2x_v1 X=(64,32) px/m Y=(-64,32) px/m; footprint 1x2; dimensions 0.92x1.92x1.50m; access edge E. Preserve exact long projected vector (540,270), depth vector (258.75,-129.375), depth/long ratio 0.47917. Show exactly FOUR distinct product shelf boards, not counting the separate low kick plate. Keep the four shelf boards at the same positions and angles as reference 1. Keep the central vertical perforated back panel and two slim end uprights. One-sided access. No roof/top cap/canopy, no products, signage, labels or extra objects. Keep broad shelf surfaces and kick plate exactly as guide; don't alter shelf size or spacing. Reference 2 is ONLY for warm soft hand-painted miniature-game shading and palette; do not borrow its objects, scene or perspective. Matte warm-white/cream painted steel, restrained charcoal kick plate, gentle soft shading; avoid glossy metallic glare, thick black outlines, exaggerated AO, photorealism. True transparent RGBA, centered full silhouette, minimum 12% fully transparent margin on each edge; no low-alpha fringe at canvas edges. No floor, shadows, glow, text, borders, checkerboard, crop or frame. Single view.
```
- Parent visual review: FAIL. Only three distinct shelf boards are visible above the base; the required fourth shelf is missing. The apparent shelf-depth ratio is visibly shorter than the guide's 0.47917 target. Alpha touches the left and bottom canvas edges, leaving no safe transparent margin there. Finish is overly glossy. The fixture remains recognizable as a single-sided, roofless EMPTY gondola.
- `comparison_guide_v10.png` places the guide and original candidate side by side at aspect-preserving display scale. This is a review sheet, not a game render.
- Not checked in Godot; anchor, game-size readability, and runtime integration remain unverified. `runtime_approved` is false.
