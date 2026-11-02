# Countertop shopping-bag dispenser — ImageGen review candidate

- One source image selected from this generation run; the second generated variation was not used or registered. `source_original.png` is copied byte-for-byte. No crop, resize, recolor, or alpha cleanup was applied. The checkerboard JPEG is an inspection-only derivative.
- Content: one ivory holder with folded translucent bags and a front pull lip, no extra objects/text. The subject reads as a shopping-bag dispenser.
- Style: **FAIL for game-ready use**. The source is highly glossy, photographic, and surrounded by a bright luminous halo, despite the game-style reference.
- Alpha: RGBA transparency is real. At alpha >=8, L/T/R/B margins are 30.60/18.46/29.04/20.21%, passing the 12% target. At alpha >=1, the faint glow reaches the bottom edge; low-alpha edge contamination FAIL.
- Projection: visible edges appear approximately isometric, but there are no calibrated control points or game-camera comparison; estimated only.
- World dimensions, countertop placement, tile footprint, anchor, and Godot display are unverified. Review only; `runtime_approved:false`.
