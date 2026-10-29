# shelf_general EMPTY projection guide v10

This construction guide uses the current game projection and the canonical `shelf_general` dimensions. It is a guide, not a runtime sprite.

- Game projection source: `scripts/presentation/iso_projection.gd`; each world metre on X and Y has the same projected length. +X is `(64,32)` and +Y is `(-64,32)` at zoom 1.
- Fixture source: `data/fixtures/mvp_v1.json`; footprint `1×2`, dimensions `0.92×1.92×1.50m`, access edge E.
- Long/depth ratio: `0.92/1.92 = 0.47917`.
- Guide vectors: long `(540,270)` and depth `(258.75,-129.375)`, slopes +0.5 and −0.5, ratio 0.47917.
- Four distinct product shelves above a separate low base; board lower vertices use positive image-Y and remain in canvas.
- Guide alpha bounds and SHA are recorded in `guide_QA.json`.
- Anchor, final world scale, Godot display size, and runtime approval are not established by this guide.
