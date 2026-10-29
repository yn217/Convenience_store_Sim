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

## Small tabletop oden warmer candidates

Issue #163 distinguishes the requested single tabletop oden pot from the incorrectly substituted large three-bay cabinet. Three Codex ImageGen candidates are now preserved:

- `oden_countertop_single_candidate_v1.png` — correct single-unit subject and recognizable oden, but camera is too near front-on.
- `oden_countertop_iso_edit_candidate_v2.png` — regenerated from v1 with a higher, more elevated camera; stronger top visibility, but not yet proven against the game's exact 2:1 projection.
- `oden_countertop_framed_candidate_v3.png` — framing-only regeneration from v2 to leave more room around the complete appliance; retains low-alpha studio haze.

All are review candidates, not runtime assets. Original images were kept intact; no non-uniform scale/crop was applied. Need actual footprint, r0 orientation/anchor calibration and Godot-size review before promotion. `runtime_approved:false`.

## Issue #157 — integrated bakery gondola candidates

Generated two new complete shelf-and-merchandise images, rather than detached package icons:

- `bread_gondola_integrated_candidate_v1.png` — the first filled shelf composition. It has rich bread variety, but the long shelf axis reads flatter than the target.
- `bread_gondola_ratio_iso_candidate_v2.png` — regenerated with explicit 1×2 footprint proportions, four product levels, shallow trays and 2:1 isometric edge targets. The long front axis looks closer, but the side/depth axis still appears too steep, and the complete silhouette is tall relative to its width (solid-alpha bbox aspect about 0.804). The bottom margin is narrow and low-alpha haze reaches the image boundary.

Issue #157's prior image set remains untouched. These new PNGs are review-only, not a canonical EMPTY/FULL sprite or runtime asset. No crop, nonuniform scaling, or alpha cleanup was applied. Exact footprint, r0 direction, ground anchor, and Godot display remain unverified. `runtime_approved:false`.

A display-only side-by-side comparison is in read_gondola_comparison.png. Both originals are fitted to view panels for inspection; the sheet is not a scale or projection calibration.

## 2026-10-29 — ATM and copier candidates

Two additional standalone candidates were generated in parallel and preserved with per-image metadata:

- `atm_candidate/atm_candidate.png` — front controls and right side are readable. Projection FAIL: perspective-like edges, converging verticals, and the base touches the bottom edge. Do not approve or stretch to fit.
- `copier_candidate/copier_candidate.png` — ADF, blue touchscreen, output area, and drawers read clearly in the intended warm painted style. Exact `iso2x_v1`, anchor, footprint, and game-scale checks remain unverified.

Both original PNGs remain unmodified, `review_only`, and `runtime_approved:false`. Per-candidate prompts, bounds, hashes, and visual findings are in each folder's `QA.json`.

## Issue #157 — empty ambient gondola shape candidates

Following the latest issue gate, two EMPTY-only concepts were generated before making another FULL shelf. Both originals are preserved without cropping or non-uniform scaling:

- `ambient_gondola_empty_candidate.png` — open four-tier shelf with no roof; shelves are still broad/deep and the alpha silhouette reaches the bottom canvas edge.
- `ambient_gondola_empty_iso_candidate_v2.png` — one regeneration aimed at shallower shelves and margin. The shelf planes still read broad, a dark edge haze remains, and the alpha silhouette again touches the bottom edge.

Both are **shape FAIL / review_only**, not an approved new reference. Exact `iso2x_v1`, world footprint and ground anchor were not calibrated. Do not use them as FULL/HALF/EMPTY state bases. Further shelf image generation should wait for the reference/shape gate to be corrected rather than scaling these candidates.

## Issue #163 — small tabletop oden warmer v4

Generated `oden_countertop_single_candidate_v4.png` as a single small countertop pan, distinct from the large 3-bay cabinet. Oden ingredients and dividers read clearly. The long front edge appears too horizontal for strict `iso2x_v1`, and low-alpha glow reaches the left canvas edge (the top-left corner pixel itself is transparent). It remains review-only; do not non-uniformly stretch it. Projection/r0 orientation/ground anchor/game-size QA are pending.

## Issue #163 — coffee machine and steamed-bun warmer candidates

Two independent image-generation candidates were added:

- `coffee_machine_candidate/coffee_machine_candidate.png` — standalone coffee machine with screen, cup bay and integrated cup stack. It reads clearly, but the finish is glossier than the target painted game art, and the alpha bounds touch the top and left canvas edges. Projection is not calibrated.
- `steamed_bun_case_candidate/steamed_bun_case_candidate.png` — small glass-front warmer with three bun trays. Product category is readable; the top housing is broad and the strict 2:1 projection is not verified. Three faint low-alpha pixels reach the left edge.

Per-image prompts, source QA and hashes are in each subfolder. These remain review-only, `runtime_approved:false`; do not connect them to runtime before projection, anchor, footprint and in-game zoom review.
