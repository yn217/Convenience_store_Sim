# shelf_general FULL integrated candidate v2

- Producer: image-generation subagent `Jason` using GPT-6 Luna; generated 2026-10-30.
- Source: `shelf_general_full_integrated_candidate_v2.png`, 1536×1024 RGBA, 2,237,552 bytes. Preserved unchanged; no crop, resize, paint-over or alpha cleanup.
- SHA-256: `3823a4a43a26d69936c28b5d11afb049712c00b057d26da21947c054b2c78c70`.
- References: v1 integrated shelf image and the existing iso2x_v1 projection guide. Their SHA-256 values are recorded in `asset_candidate.json`.
- The agent's short prompt brief: four-tier single-sided open gondola, integrated shelf and goods, thin frontal pouches, transparent background, at least 12% clear margin on all sides, no glow/floor/shadow, no real logos or text. The actual low-level prompt emitted by the image service was not retained.

## QA result: FAIL

- Shelf and goods are one composed image; four tiers are densely stocked. This fixes the separate-floating-package-card problem.
- The lower-tier product fronts are flatter than v1 and no drinks/cartons dominate, but several packages still appear box-like.
- Main long edges visually slope about -0.23; the game contract expects ±0.5 for the relevant projected axis. This is a visual estimate, not a calibrated measurement.
- Alpha>127 bounds `[312,54,1348,1022]` on 1536×1024 leave margins L20.3%, R12.2%, T5.3%, B0.2%. Safe 12% vertical margins fail. A dark glow/fringe remains.
- `alpha_preview_v2.png` shows white/checkerboard composites. `comparison_v1_v2.png` shows v1/v2 on the same canvas and scale. Neither derivative modifies the source.
- Intended fixture contract: `shelf_general`, 1×2 tiles, 0.92×1.92×1.50m, access edge E. Actual scale, anchor, exact projection, Godot display and EMPTY/HALF synchronization remain unchecked.
- Review only; `runtime_approved:false`.
