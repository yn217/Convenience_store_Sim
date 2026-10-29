# Codex ImageGen candidates — 2026-10-29

These are non-runtime visual candidates generated with the built-in Codex image generation tool. They are preserved for review; none is approved for shipping. No game code or existing art was changed.

## Files

- `hot_snack_three_bay_candidate_v1.png` — three-bay heated case with food integrated into one sprite.
- `hot_snack_three_bay_projection_edit_v2.png` — image-to-image attempt to make the same case follow the 2:1 iso axes.
- `open_snack_gondola_candidate_v1.png` — one-sided open snack gondola with merchandise integrated into the shelves.
- `qa.json` — dimensions, transparency, hashes, and review status.

## Visual QA

The generated images have transparent corners and show integrated shelf/case plus products. They are not calibrated game assets. The hot-snack pair still reads close to a shallow, front-facing perspective; their long axis is visibly flatter than the target 2:1 iso slope. The gondola has a more useful stocked-shelf composition and no roof, but its long base edge also appears flatter than the required game axis, and the illustration/rendering style differs from the target game's compact sprite look. The generation model did not obey exact orthographic grid constraints even when called out explicitly.

Do not correct these projection mismatches by stretching the artwork. Keep all three as review-only; runtime_approved remains false. Use these as visual direction only, or generate a new image with a stronger explicit 2:1 grid construction.

The gondola candidate also shows low-alpha pixels extending to the left canvas edge and has only a very small bottom margin at solid-alpha thresholds. No alpha cleanup or crop was applied, so the generated original remains intact.

## Additional style-reference candidate

- `open_snack_gondola_style_ref_candidate_v2.png` was generated using the supplied game screenshot as a style reference. It is the strongest of these trials: all products are integrated into the shelf, the top is open, and the long shelf axis looks closer to the target 2:1 iso slope. A visual estimate is not a calibration; no world-space landmarks, confirmed footprint, r0 verification, or Godot-size comparison is available. The transparent source also contains a very low-alpha haze reaching the canvas edge. Keep it review-only and preserve the original.
