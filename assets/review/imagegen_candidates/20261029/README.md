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

## Issue #163 — microwave and postbox candidates

The next uncovered equipment candidates were generated by two subagents in parallel:

- `microwave_candidate/microwave_candidate.png` — front door, controls and tray are readable; depth projection fails the strict game iso2x target and reflective highlights are strong.
- `postbox_candidate/postbox_candidate.png` — standalone cylindrical red postbox with mail slot and lower access hatch; readable, but projection is not calibrated.

Both original images and per-asset QA are preserved without scaling. They remain `review_only`, `runtime_approved:false` pending actual game-camera, footprint, anchor and zoom checks.

## Issue #163 — umbrella stand candidate

`umbrella_stand_candidate.png` is a standalone umbrella rack with several umbrellas and a drip tray. The category reads clearly. A low-alpha background glow reaches the left alpha bound, and exact `iso2x_v1` projection/game scale remain unverified. Original image preserved; review-only, `runtime_approved:false`.

## Issue #163 — hand truck and reusable crate candidates

- `hand_truck_candidate/hand_truck_candidate.png` — a hand truck carrying blue beverage crates. The equipment is identifiable, but the load hides much of the frame and one wheel; the silhouette touches the lower image edge, and the iso2x projection is not calibrated.
- `plastic_crate_stack_candidate/plastic_crate_stack_candidate.png` — three open-lattice reusable blue crates. The openings and rims read as crates rather than solid cuboids. Low-alpha blue fringe extends beyond the main silhouette, the color finish is cool/glossy, and exact game projection is unverified.

Both remain review-only. Preserve the originals; do not stretch them to force projection agreement. Per-image QA is stored in each subfolder.

## 2026-10-29 — crate, hand truck and store-prop generation iteration

Three new direct Codex ImageGen outputs were reviewed and preserved with exact file metadata:

- `plastic_crate_stack_candidate/plastic_crate_stack_candidate_v2.png` — three open lattice crates remain recognizable, but the blue halo blooms to the canvas edge and bottom; glossy cool finish and projection remain unsuitable.
- `hand_truck_candidate/hand_truck_empty_candidate_v2.png` — empty dolly form is clear, but the checkerboard was baked into an RGB image and the shape is not strict iso2x.
- `shopping_basket_stack_candidate.png` — three nested retail baskets on a wheeled rack; checkerboard is baked into RGB and finish is too glossy/cool.
- `plant_candidate/plant_candidate.png` plus `plant_checkerboard_edit_v2.png` — plant art is legible, but both generation and attempted edit keep an opaque checkerboard (RGB, no alpha). The edit made the pattern denser, so it is a generation failure.

These records diagnose an image-generation limitation; none is a usable transparent sprite. Original outputs are unchanged, not cropped or stretched, and remain `review_only` / `runtime_approved:false`. See per-candidate `*_QA.json` and `qa.json` for dimensions and hashes.

## 2026-10-29 — transparent-background generation retry

Using the generator's explicit transparent-background option produced valid RGBA results, unlike the earlier opaque checkerboard outputs:

- `plant_candidate/plant_candidate_alpha.png` — warm hand-painted plant in a pot, with real alpha and generous margin. A faint green edge fringe remains; projection/anchor/game scale are not calibrated.
- `promo_sign_candidate/promo_sign_candidate.png` — complete hot-snack A-frame promo sign with real alpha. The front face is perspective-oblique and does not yet meet strict iso2x calibration.

Both are review-only candidates with per-image QA and SHA-256 in `qa.json`; neither is runtime approved.

## Issue #163 — additional candidates with true alpha

Explicit transparent-background generation produced three valid RGBA images:

- `plant_candidate/plant_candidate_alpha.png` — warm potted plant, clear and full frame. A faint green fringe is visible; game projection and anchor are uncalibrated.
- `promo_sign_candidate/promo_sign_candidate.png` — A-frame hot-snack promo board with abstract food artwork. Full silhouette and true alpha; front face remains too perspective-oblique for strict iso2x.
- `atm_candidate/atm_transparent_candidate_v2.png` — ATM controls and red/gray housing read clearly with true alpha. Camera has perspective convergence, so projection fails the game target.

The PNGs remain unmodified review candidates. Each has a per-image QA record and SHA-256 entry in `qa.json`; `runtime_approved:false`.

A second agent-generated sign concept is preserved at `agent_sign_candidate/agent_sign_candidate.png`. It has genuine RGBA alpha and a complete A-frame silhouette, but low-alpha fringe touches the top and its perspective is not calibrated. Its QA is kept beside the image; it remains review-only.

## Issue #163 — shopping baskets with true transparency

`shopping_basket_stack_candidate_alpha.png` is the transparent-background retry for the earlier opaque-checkerboard attempt. It shows three nested perforated blue hand baskets on a small caster base, with valid RGBA alpha. A blue fringe touches the left canvas edge; the camera remains perspective-like and glossy, so this is review-only until projection and game-scale calibration.

## Issue #163 — reusable crate stack transparent retry v3

`plastic_crate_stack_candidate/plastic_crate_stack_candidate_alpha_v3.png` was generated with explicit transparent-background output and a warmer, matte finish. Three open lattice crates are legible. There is still a diffuse blue alpha haze around the object (the alpha>=1 silhouette is substantially wider than alpha>=8), and camera projection is not proven against iso2x_v1. Review-only; no alpha cleanup/cropping or scale warp was applied.

## Additional checkout equipment — POS terminal

`pos_terminal_candidate/pos_terminal_candidate.png` combines a touchscreen, keypad and receipt printer in one isolated image candidate. True RGBA alpha is present, but a low-alpha haze surrounds the art and the strong perspective/gloss do not match a calibrated iso2x game sprite. Kept review-only with alpha threshold bounds and SHA-256 in its QA record.

## Issue #163 — bin and umbrella variations from parallel generation

- `agent_waste_bin_candidate/waste_bin_candidate.png` — two-compartment recycling bin; both top openings and pictograms read, with real alpha and margin. It is glossier and more perspective-like than the target sprite projection. The game already contains a simple `trash_recycle_bins` placeholder, so this is a visual replacement study only.
- `agent_umbrella_candidate/umbrella_stand_candidate.png` — three folded umbrellas and drip tray in a warm hand-painted style; complete silhouette and real alpha. Thin colored fringe remains and projection/scale are uncalibrated. This is a second visual direction alongside the earlier umbrella candidate.

Both remain review-only. Per-agent QA and measured file metadata are retained; neither changes the generated runtime prop or its approval state.

## ATM projection-only edit v3

`atm_candidate/atm_projection_edit_candidate_v3.png` is an edit of the existing ATM candidate intended to adjust projection only. The front controls and red panels remain legible, but strong perspective remains and nonzero alpha touches the left and bottom canvas edges. It is retained as a failed review iteration; it must not replace the prior source or be stretched/cropped to conceal the mismatch.

## Issue #163 priority A — single fryer candidate

`fryer_candidate/fryer_candidate.png` is a standalone double-basket countertop fryer, separate from the multi-bay hot-snack case and coffee machine. The controls and baskets are readable with true RGBA; a low-alpha halo reaches the left canvas edge, the camera remains perspective-like, and exact game scale/projection are unverified. Kept review-only with no runtime changes.

## Issue #163 P0 — single tabletop oden pot retry v5

`oden_countertop_candidate/oden_countertop_single_alpha_candidate_v5.png` is explicitly one small countertop pot with four ingredient compartments, distinct from the large three-bay warmer cabinet. It has true RGBA alpha and the category reads clearly, but a low-alpha halo reaches left/bottom edges and its steep perspective does not match iso2x_v1. Review-only; do not use it as the large-case asset or distort it to fit.

`oden_countertop_single_projection_edit_v6.png` is an angle-only edit of the v5 single pot. It reveals more of the front vertical face while preserving the four food sections, but perspective remains steep and alpha reaches left/bottom canvas edges. Retained separately; no crop or warp was applied.


## 2026-10-29 — ongoing Codex ImageGen candidates

- `agent_coffee_v2/coffee_machine_candidate.png` — standalone warm-painted coffee appliance; readable, but faint alpha fringe and unverified iso projection remain.
- `agent_bun_v2/steamed_bun_warmer_candidate.png` — single compact two-tray steamed-bun warmer; category reads clearly, but the halo/gloss and uncalibrated angle keep it review-only.
- `microwave_candidate_v2/microwave_transparent_candidate_v2.png` — second compact microwave candidate. Controls and door are clear; its near-front view and dark halo fail the game projection/style gate. Original v1 is unchanged.
- `integrated_snack_gondola_candidate/integrated_snack_gondola_candidate.png` — complete dense shelf and products in one image, as requested. Composition is useful, but the projection is near-front, the halo is strong, the alpha silhouette reaches the bottom edge, and some generated package lettering is distorted. It is not suitable as a calibrated sprite.

All are preserved as review-only candidates. No cropping, anisotropic scaling, runtime hookup or approval; `runtime_approved:false`. Per-image measurements and hashes are in each folder's `QA.json`, and the index is `qa.json`.

- `agent_oden_v7/oden_countertop_single_candidate_v7.png` — single countertop oden unit with divided ingredients is clear, but the finish is photoreal/glossy and its elevated oblique view fails the calibrated game projection. Shape/style reference only; review-only.

- `integrated_snack_gondola_candidate_v2/integrated_snack_gondola_candidate_v2.png` — projection-focused regeneration from v1. The stocked shelf remains coherent and the angle improved slightly, but the long axis is still too flat and a studio halo remains. Composition reference only; no crop or stretch.

- `integrated_snack_gondola_candidate_v3/integrated_snack_gondola_candidate_v3.png` — image-to-image regeneration using the target game screenshot as style reference. It reads as a stocked double-sided gondola, which is structurally useful, but the long-axis slope is still too flat and a strong halo remains. Review-only; no crop or stretch.

- `agent_atm_v3/atm_candidate_v3.png` — recognizable red-white ATM with screen, keypad and cash/card slots. True alpha and no edge clipping, but perspective convergence means strict iso2x_v1 is not met; glossy highlights remain. Review-only.

- `umbrella_stand_candidate_v2/umbrella_stand_candidate_v2.png` — three-color umbrellas and sleeve bin read clearly in a warmer illustrated style. No edge clipping; a dark halo remains and projection is uncalibrated. Review-only.

- `agent_copier_v2/copier_candidate_v2.png` — clear ADF, touchscreen, output tray and paper drawers; near-clean alpha; strict iso2x_v1 and in-game scale remain unverified.
- `agent_fryer_v2/fryer_candidate_v2.png` — recognizable single two-basket fryer, but excessive top exposure, metal gloss and edge glow fail the target style/projection.

- `freezer_chest_candidate_v1/freezer_chest_candidate_v1.png` — recognisable paired-lid frozen-food chest case. The overhead view, shallow long-axis slope and studio halo fail projection/style calibration; review-only.

- `agent_freezer_upright_v1/upright_glass_door_freezer_candidate_v1.png` — full glass-door freezer with seven stocked rows; readable contents and near-clean alpha, but projection and in-game scale remain uncalibrated. Review-only.
