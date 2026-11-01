# Capsule toy 3-machine FULL candidate — review only

Created with built-in ImageGen. The ATM image was used only as a style reference. `source_original.png` is unchanged and retains the generated RGBA alpha.

## Focused QA
- Correct subject count: exactly three adjacent capsule dispensers; colorful capsules remain inside the globes. The set reads as one connected fixture, not detached merchandise cards.
- Overall art is clear and readable, though the bodies use block-like machine housings (appropriate to the equipment, not product packages).
- Projection **FAIL**: the visible long X axis is down-right, but appears roughly +0.24 slope versus `iso2x_v1` target +0.5. Estimate is visual only; do not anisotropically scale.
- Raw alpha margins and pixel thresholds are in `qa_report.json`; any padded preview is canvas-only and cannot repair crop or geometry.
- Nominal game contract: footprint 2×1, 1.84×0.92×1.60m, access S. Generated dimensions, ground anchor and Godot rendering remain unverified. `runtime_approved:false`.
