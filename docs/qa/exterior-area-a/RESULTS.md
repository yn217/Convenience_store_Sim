# Area A / storefront follow-up QA (2026-10-29)

## Near-side storefront promotions

Added two small code-drawn promotion posters to closed near-side window panes. Placement uses wall-plane coordinates, checks the entrance span, and keeps the posters within glazing height; text is rendered by the game font. The posters avoid the interactive doorway and do not depend on generated lettering. Actual 1600x900 captures use the same 16:00 frozen setup:

| Footprint | Capture | Observation |
|---|---|---|
| 12x10 | `storefront-posters-12x10-1600x900-2026-10-29.png` | Both posters stay on the near glazing and clear the center entrance. |
| 16x12 | `storefront-posters-16x12-1600x900-2026-10-29.png` | Same placement on the default footprint; posters are visible at whole-store scale but smaller than the target's large promotion banners. |
| 20x16 | `storefront-posters-20x16-1600x900-2026-10-29.png` | Both posters remain attached to the glazing; the broad ground and sparse near-side promotions remain visibly different from the target. |

Focused `test_store_decor` passed 24 tests / 496 assertions, including east/south entrance orientations across all three footprints. This is a detail pass only; the remaining differences table still records open storefront, planting, pavement and surrounding-scene work.

## Fascia brand mark follow-up

Added a small blue-and-yellow house mark beside the fictional store name. Its panel is placed on the fascia wall plane and chooses the side away from the active entrance; if neither side has room it is omitted. The mark is code-drawn, so no inaccurate generated lettering is baked into the art.

Actual Godot 4.7.2 capture at 20x16 / 1600x900: `fascia-brand-mark-20x16-1600x900-2026-10-29.png`. `test_store_decor` passes 23 tests / 412 assertions, including mark bounds and clearance at 12x10, 16x12, and 20x16 for all four entrance directions. The full suite was not run. At whole-store scale the mark is small; matching the target's exact logotype and richer fascia/window framing remains future art work.

## Near-side automatic-door glazing follow-up

Added two translucent sliding leaves to the near-side entrance facade. They sit in the side pockets and leave a 0.7m clear central route; this is a presentation-only wall-plane detail and does not change entrance tiles, customer routing, or input. The existing entrance jamb and top canopy remain in place.

Actual Godot 4.7.2 capture: `near-entrance-sliding-doors-16x12-1600x900-2026-10-29.png`. Focused `test_store_decor` passed 22 tests / 376 assertions; `test_shell_camera_input` passed 10 / 96, including floor selection, panning and UI input blocking. No full suite was run. The leaves are static and the reflections remain subtle at whole-store scale; automatic opening animation is still absent.

## Resolution, operation, and performance follow-up

Actual Godot 4.7.2 captures at 16:00, 20x16, whole-store camera:

| Viewport | Capture | Observation |
|---|---|---|
| 1280x720 | `complete-view-1280x720-20x16-2026-10-29.png` | Store, entrance road, and grove remain in frame. |
| 1920x1080 | `complete-view-1920x1080-20x16-2026-10-29.png` | Same world anchors and wall occlusion at the larger viewport. |

Focused operation checks passed without running the full suite: `test_shell_camera_input` 10 tests / 96 assertions; `test_overlays` 9 / 44; `test_panel_modes` 11 / 55; `test_build_ui` 9 / 69. These cover floor selection after camera movement, object picking, input blockers, panel transitions, and construction placement. `test_overlays` emitted two Viewport-not-inside-tree engine warnings during setup but reported 0 failures.

The fixed 600-frame performance benchmark at 1920x1080 (`perf-upright-grove-v2-clean-1920x1080-2026-10-29.json`) measured 16.08 median FPS at x1 and 11.06 at x4; x4 median frame time was 90.44ms, with 1061 draw calls and 8.23ms presenter draw time. The diagnostic run (`perf-upright-grove-v2-probe-1920x1080-2026-10-29.json`) found that hiding `FixturePresenter` reduced a 60-frame sample from 96ms to 59ms, while hiding customer and stock data barely changed it. A historical same-condition record from 2026-10-27 reported 31.07 median FPS at x4. These are whole-game numbers and do not establish which recent feature is responsible. Performance remains an open quality gate and needs profiling before approval.

## Exterior ground batching follow-up (2026-10-29)

The full-screen ground variation used one texture draw per tile on every redraw. It is now assembled into a camera-phased `ArrayMesh` during backdrop sync and submitted as one textured mesh; opacity remains 24%, UVs repeat per tile, and panning rebuilds the same phase from the world camera origin. The 20x16 runtime capture `ground-mesh-batch-20x16-1600x900-2026-10-29.png` confirms the road, paved apron, wall occlusion, and grove retain their prior ordering and appearance. Focused `test_backdrop_layer` passes 23 tests / 333 assertions, including viewport coverage, UV count, alpha, and pan phase.

An A/B/A runtime probe with 20 fixtures and 30 customers at 1920x1080 recorded 87.01ms/frame with tiled draws, 83.08ms with batching, and 89.32ms after batching was re-enabled (`perf-ground-batching-ab-1920x1080-2026-10-29.json`). The range shows a small improvement tendency but also substantial frame-time noise; the x4 600-frame median remains 95.72ms (10.45 FPS). This change does not close the performance gap against the earlier 31.07 FPS result, and no cause is assigned to the entire regression.

Two grouped ImageGen panorama candidates and one edge-cleanup edit were also inspected. They had conspicuous lime/yellow halos on transparent silhouettes, so none was copied into the project or integrated. The existing clean-edge runtime panel remains in use.

## Upright planting alignment

The grouped planting strips now fit their root endpoints to each projected store edge while keeping the image's vertical axis upright on screen. The previous rotation transformed the entire tree image along with the ground line, which made trunks lean on the isometric sides. The affine shear changes the strip's ground-line angle without moving the z=0 anchor; store walls continue to cover the roots and lower stems.

Actual Godot 4.7.2 captures at 1600x900, 16:00:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `upright-grove-v2-12x10-1600x900-2026-10-29.png` | Compact panel follows the wall angle; trunks stay upright and the wall covers the planting base. |
| 16x12 | `upright-grove-v2-16x12-1600x900-2026-10-29.png` | Intermediate panel uses the same upright transform and stays aligned at both ends. |
| 20x16 | `upright-grove-v2-20x16-1600x900-2026-10-29.png` | Long panel meets both wall endpoints without rotating the trees. |
| 20x16, camera panned | `upright-grove-v2-pan-20x16-1600x900-2026-10-29.png` | World anchors follow the moved camera while the store and grove remain in frame. |

Focused `test_backdrop_layer` passed 22 tests / 327 assertions, including all four side transforms and pan behavior. No full suite was run. New image-generation candidates were not integrated: several had a checkerboard baked into the image or visible colored fringes around transparent edges.

## Grouped planting-band candidate screening (2026-10-29)

Two image-generation subagents produced grouped planting strips; a separate built-in generation and one edge-cleanup edit were also inspected. All four new outputs were rejected: the transparent edges still contain bright yellow/green color spill, and the direct-generation sample also has detached transparent holes or a background haze. None was copied into the runtime asset set. The existing grouped panels remain in use until a cleaner cutout can be placed at the same ground anchors and compared in the game.

## Planting and road-side panel by entrance orientation

Actual Godot 4.7.2 captures at 1600x900, 16:00, 20x16. Each entrance move returned success, and the captured road apron follows the selected store edge while the planting remains on non-road sides.

| Entrance | Capture |
|---|---|
| West | `planting-entry-west-20x16-1600x900-2026-10-29.png` |
| North | `planting-entry-north-20x16-1600x900-2026-10-29.png` |
| East | `planting-entry-east-20x16-1600x900-2026-10-29.png` |
| South | `planting-entry-south-20x16-1600x900-2026-10-29.png` |

`planting-night-south-20x16-1600x900-2026-10-29.png` checks the same scene at 22:00. The planted canopy darkens with the rest of the environment; no magenta-key halo is apparent at full-scene scale. Seasonal art variants and a focused interaction pass remain outstanding.

## Runtime captures

All images are actual Godot 4.7.2 captures at 1600x900, 16:00, whole-store camera, frozen simulation.

| Store size | Capture |
|---|---|
| 12x10 | `after-12x10-1600x900.png` |
| 16x12 | `after-16x12-1600x900.png` |
| 20x16 | `after-20x16-1600x900.png` |

`pan-zoom-16x12.png` checks the combined exterior while the camera is zoomed and panned. `build-mode-16x12.png` records the same exterior while the construction catalogue is open. Entrance-orientation captures were excluded because the command-line entrance state was not reliable.

The planting anchor and V-branch coverage were re-captured from the current code at 1600x900:

| Store size | Runtime capture |
|---|---|
| 12x10 | `roots-12x10-2026-10-29.png` |
| 16x12 | `roots-16x12-2026-10-29.png` |
| 20x16 | `roots-20x16-2026-10-29.png` |

`roots-pan-zoom-16x12-2026-10-29.png` verifies that the ground anchor follows a translated, zoomed camera. Both V branches are tested independently. The root point stays fixed at z=0 behind the far corner, while the back walls cover the lower planting. The fixed-height follow-up below supersedes the earlier per-footprint scale.

Viewport-size captures at 16x12 were also taken after the import cache was rebuilt:

| Viewport | Runtime capture | Observation |
|---|---|---|
| 1280x720 | `resolution-1280x720-16x12-2026-10-29.png` | Full exterior remains in frame; lower HUD cards are denser. No planting gap or clipped V endpoint observed. |
| 1920x1080 | `resolution-1920x1080-16x12-2026-10-29.png` | Full exterior remains in frame with the same ground anchor and wall occlusion. |

## Changes

- The Area A parking/sidewalk artwork now fits by a rotation and one uniform scale. Its measured frontage endpoints map to the selected store edge endpoints for 12x10, 16x12, and 20x16. The geometry check also covers all four entrance sides. The prior small vertical shear is removed, so the artwork is not distorted to force the edge angle.
- The combined image contains the static parking paint and wheel stops. StoreDecor no longer emits a second set of those markings over the image; the parked car remains an independent world-positioned sprite.
- Low cut-away storefront glass gets subtle diagonal reflections. They remain within closed panes below the low frame and leave the south entrance opening clear.

## Focused checks

| Check | Tests | Assertions | Failures |
|---|---:|---:|---:|
| `test_backdrop_layer` | 13 | 86 | 0 |
| `test_store_decor` | 19 | 296 | 0 |

After the V-branch endpoint assertions were added, `test_backdrop_layer` was rerun: 14 tests, 91 assertions, 0 failures.

Only these focused suites were run. The full test suite was not run.

## Ground-anchored grove follow-up (2026-10-29)

The grouped roadside greenbelt PNG is fitted uniformly from its authored ground-contact endpoints to world-ground endpoints outside the road and outer sidewalk. The wall and roadway are painted afterward, so the trunk and shrub bases can be occluded. A generated single-piece sidewalk strip replaces the metre-by-metre outer-walk polygons; its measured centerline endpoints map to the projected world strip for each store size, with a uniform scale. The forecourt fill is restricted to the frontage to avoid a broad asphalt wedge at the road end. Asset anchors and dimensions are recorded beside both images in their `asset.json` files.

Actual runtime captures at 1600x900:

| Store size | Capture | Observation |
|---|---|---|
| 12x10 | `grove-sidewalk-12x10-1600x900-2026-10-29.png` | A compatible minimal register/shelf layout is used so the store opens. The full exterior remains visible and the grove roots stay behind the wall. |
| 16x12 | `grove-sidewalk-16x12-1600x900-2026-10-29.png` | Generated sidewalk strip and rooted grove visible; wall occludes the lower planting. |
| 20x16 | `grove-sidewalk-20x16-1600x900-2026-10-29.png` | Both rear branches and the generated sidewalk strip reach the store ends without a visible root gap. |
| 20x16, zoomed and panned | `grove-sidewalk-panzoom-20x16-2026-10-29.png` | Ground-anchored planting and sidewalk follow the camera; no wall gap appears during the changed view. |
| 20x16, east entrance | `entrance-east-20x16-1600x900-2026-10-29.png` | Entrance move succeeded; road/sidewalk pivot with the frontage, while the rear planting keeps both wall endpoints covered. |
| 20x16, north entrance | `entrance-north-20x16-1600x900-2026-10-29.png` | Entrance move succeeded; the rotated road remains connected to the store edge. The existing side planting reads as spaced planters from this view, not a continuous bed. |

Focused placement checks cover all four sides for 12x10, 16x12, and 20x16 and assert both greenbelt and sidewalk endpoints against projected world positions. `test_backdrop_layer` currently passes 17 tests / 173 assertions. The 12x10 capture uses a minimal compatible register/shelf layout so the store reaches the running business state. East/north entrance captures also show the running state; north-side planting density is still lower than the target mockup.

## Roadside greenbelt iteration (2026-10-29)

An additional generated group was tested as a replacement for the initial roadside tree strip. It adds a lower, denser line of shrubs and trees beyond the curb, closer to the target's planted street edge. At the actual in-game scale its source color fringe is not visually apparent, and the road/curb cover the irregular base. Captures cover 12x10, 16x12, and 20x16 plus a zoomed/panned 20x16 view:

| Size / view | Capture |
|---|---|
| 12x10 | `greenbelt-test-12x10-1600x900-2026-10-29.png` |
| 16x12 | `greenbelt-test-1600x900-16x12-2026-10-29.png` |
| 20x16 | `greenbelt-test-20x16-1600x900-2026-10-29.png` |
| 20x16 zoomed/panned | `greenbelt-test-panzoom-20x16-2026-10-29.png` |

Other generated flowering-border candidates remain unintegrated because their high-saturation transparency fringe is visible in the source artwork and they duplicate planting already present at the parking corners.

## Fixed-scale roadside greenbelt (2026-10-29)

The grouped roadside tree strip now has a fixed 18m world length, centered on the selected store edge. Its source contact points map to the outside ground plane at z=0, and its uniform scale follows camera zoom rather than store-edge length. This keeps the tree height consistent for 12x10, 16x12, and 20x16 while extending beyond both ends on the smaller footprint. The wall and road remain in front of the roots.

Actual runtime captures at 1600x900:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `fixed-scale-12x10-1600x900-2026-10-29.png` | The strip reaches past both wall endpoints; the extra length is split evenly. Roots remain behind the wall/road. |
| 16x12 | `fixed-scale-16x12-1600x900-2026-10-29.png` | The previous medium-size fit is retained at the same camera zoom. |
| 20x16 | `fixed-scale-20x16-1600x900-2026-10-29.png` | The same authored world length is centered on the longer edge; the roots stay occluded. |
| 20x16, camera panned | `fixed-scale-pan-20x16-1600x900-2026-10-29.png` | The roadside strip follows the store camera while lower planting stays behind the street edge. |

Additional generated transparent candidates were first rejected because their edge fringes remained prominent at source scale. One denser strip was later tested in the running game and accepted as `rear_greenbelt_group_v2`; another V-shaped boundary candidate with a visible high wall remains unintegrated.

## Denser roadside greenbelt v2 (2026-10-29)

The v2 strip adds varied tree crowns and a denser hedge with small flowers. It replaces the earlier grouped roadside strip while retaining the fixed 18m world length, ground endpoint mapping, and camera-follow behavior. Source edge fringing is still present, but it was not visually distracting at the actual in-game scale; roots remain occluded by the existing wall/road order.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `greenbelt-v2-12x10-1600x900-2026-10-29.png` | The centered strip extends beyond both short-edge endpoints; lower foliage is hidden behind the street edge. |
| 16x12 | `greenbelt-v2-16x12-1600x900-2026-10-29.png` | Denser varied foliage is visible behind the road; the store-edge angle remains aligned. |
| 20x16 | `greenbelt-v2-20x16-1600x900-2026-10-29.png` | The same world-space height and anchor placement are preserved on the longer store. |
| 20x16, camera panned | `greenbelt-v2-pan-20x16-1600x900-2026-10-29.png` | The group follows the camera; no root gap opens. |

The v2 row improves the planted edge but does not fill the wide ground around the whole scene. The textured green field still needs more distant planting and street structures to match the reference.

## Fixed world-height rear planting (2026-10-29)

The rear V image now uses one uniform scale derived from the largest supported footprint (20x16), instead of scaling tree height to each store's edge. The ground anchor remains at the same world point and follows camera movement; the canopy is approximately 8.09m above ground against the 2.6m back wall. The shorter store edges show extra planted scenery beyond their wall ends. This preserves source proportions and covers the long side without stretching the image.

Actual Godot captures:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `fixed-height-12x10-1600x900-2026-10-29.png` | Roots remain behind the walls; the fixed canopy is visibly larger than the former size-fitted version and extends beyond the short walls. |
| 16x12 | `fixed-height-16x12-1600x900-2026-10-29.png` | Tree height matches the other footprints; there is no wall gap at either V endpoint. |
| 20x16 | `fixed-height-20x16-1600x900-2026-10-29.png` | Long edge coverage is retained with the same 8.09m canopy height. |
| 20x16, camera panned toward back wall at 1.2x zoom | `fixed-height-highzoom-pan-20x16-1600x900-2026-10-29.png` | The planted roots stay attached to the projected world anchor; the far-wall canopy is still visible. |
| 16x12, 1280x720 | `fixed-height-16x12-1280x720-2026-10-29.png` | No endpoint gap or clipped root line in the smaller viewport. |
| 16x12, 1920x1080 | `fixed-height-16x12-1920x1080-2026-10-29.png` | Same geometry at the larger viewport. |
| 16x12, 0.5x zoom | `fixed-height-lowzoom-16x12-1600x900-2026-10-29.png` | The store and canopy scale down together; world-space tree height remains 8.09m. |

An additional live capture pass compared the same fixed-height placement on all three requested sizes. A trial scale based on the 16x12 reference was rejected: it reduced the 12x10 overhang, but left the 20x16 right V edge short and failed the endpoint assertion. The 20x16 coverage scale remains authoritative.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `refheight-12x10-1600x900-2026-10-29.png` | Roots stay behind the far wall and the canopy clears it; extra garden is visible beyond the shorter wall ends. |
| 16x12 | `refheight-16x12-1600x900-2026-10-29.png` | Both V edges meet the wall endpoints and the tree scale remains unchanged. |
| 20x16 | `refheight-20x16-1600x900-2026-10-29.png` | The long right wall endpoint remains covered without stretching the source art. |
| 20x16, camera pan and 1.2x zoom | `refheight-pan-20x16-1600x900-2026-10-29.png` | Camera pan/zoom follows the store and does not change the world-space root anchor; this close view pans toward the store interior. |

`rear-planting-12x10-comparison-2026-10-29.png` compares the target crop, the earlier size-fitted placement, and fixed-height placement. It shows the reduced 12x10 canopy scale before the rejected 16x12 trial; retain the live 20x16 coverage scale to keep the longest supported wall continuous.

`tools/capture_screen.gd` now applies `--zoom` after `--whole`, so the zoom captures exercise the requested camera scale instead of silently returning to whole-store fit.

The generated PNG still has isolated bright green edge pixels at the source silhouette; at runtime scale the remaining fringe is limited but should be improved in a later asset pass. The 12x10 overhang is the cost of one undistorted image covering the full 20x16 range; reducing it without exposing the longer wall requires a different authored V asset or a segmented art treatment.

## Textured exterior ground v2 and daylight comparison (2026-10-29)

A generated olive-green ground texture v2 was first introduced over the exterior fill at 16% opacity. It adds finer leaf shadows and small sakura flecks. Its tile phase follows the camera origin. Opposite-edge RGB differences are slightly lower than v1 on average, but the source is not mathematically seamless; at the initial 16% opacity no prominent repeat boundary was seen in the 1600x900 runtime views. The v1/v2 in-game crop comparison is `ground-texture-v1-v2-runtime-comparison-2026-10-29.png`; the current 24% presentation is recorded below.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10, 16:00 | `daylight-ground-v2-12x10-1600x900-2026-10-29.png` | Canopy roots remain hidden, the canopy clears the wall, and the overlay preserves the road and paving colors. |
| 16x12, 16:00 | `daylight-ground-v2-16x12-1600x900-2026-10-29.png` | Fine ground variation is visible around the full exterior without hiding assets. |
| 20x16, 16:00 | `daylight-ground-v2-20x16-1600x900-2026-10-29.png` | Same texture density and opacity at the largest supported footprint. |
| 20x16, zoomed/panned | `daylight-ground-v2-pan-20x16-1600x900-2026-10-29.png` | The texture follows the camera origin while store, road, and UI remain visible. |

For time-of-day fidelity, the new captures use 16:00 to compare with the supplied 16:28 mockup. `daylight-16x12-1600x900-2026-10-29.png` and `daylight-20x16-1600x900-2026-10-29.png` retain the previous ground v1; `mockup-daylight-comparison-20x16-2026-10-29.png` places the supplied image next to the 20x16 runtime. It shows meaningful progress in garden density, parking markings, and daylight color, alongside remaining differences in camera framing, storefront glazing, facade signs, and street props. The comparison is visual rather than pixel-aligned because the mockup and game use different store layouts.

The region-by-region target/current overview and prioritized next actions are in [`REMAINING_DIFFERENCES.md`](REMAINING_DIFFERENCES.md), with its image sheet at `regions-target-vs-daylight-20x16-2026-10-29.png`.

## Storefront fascia label readability (2026-10-29)

The existing fictional store-name text on the near-side fascia now uses 32px authored text instead of 24px. Its white backing panel extends 5.2m along the wall plane. Placement remains centered on the projected wall; no screen-position offset or window/entrance geometry changed.

| Store size | Capture | Observation |
|---|---|---|
| 12x10 | `fascia-label-12x10-1600x900-2026-10-29.png` | Label remains inside the fascia on the shorter wall. |
| 16x12 | `fascia-label-16x12-1600x900-2026-10-29.png` | Name stays centered with the existing glass and entry opening. |
| 20x16 | `fascia-label-20x16-1600x900-2026-10-29.png` | Larger signage is visible at full-scene fit; updated in the daylight comparison. |

The fictional name improves fascia readability but does not reproduce the target's separate yellow/blue brand mark or promotional lettering.

Two long generated facade band candidates were not integrated. Both are single strips with perspective and material rendering that do not yet match the game's modular wall construction closely enough; the second also did not follow the requested module dimensions. A genuinely tileable facade unit still needs a separate generation and placement pass.

The v2 texture softens the remaining green field, but does not replace it with the target's continuous flower beds, full-depth planting or street structures. These remain visible differences for the final review.

## Pole sign service panels (2026-10-29)

The pole sign now uses three distinct service-color panels below the blue store-name panel: tobacco, alcohol, and ATM. The labels are rendered as separate text elements and increased to 16px for legibility at the fitted game camera. The 20x16 in-game capture is `pole-sign-services-20x16-1600x900-2026-10-29.png`. This improves the target's stacked sign hierarchy; the fictional store mark and richer sign materials remain differences.

## Exterior ground texture contrast (2026-10-29)

The same camera-following ground texture was increased from 16% to 24% opacity. This makes the broad outside fill read more like uneven grass and soil while keeping road, sidewalk, and planting layers distinct. The 16:00 runtime captures below cover all three footprints; the 20x16 low-zoom/panned capture checks the overlay across a wider exterior view. No strong repeat boundary stood out in these views. The texture still does not substitute for the target's full flower beds and surrounding street scenery.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `ground-opacity-24-12x10-1600x900-2026-10-29.png` | Fine grass flecks remain visible outside the shorter footprint. |
| 16x12 | `ground-opacity-24-16x12-1600x900-2026-10-29.png` | Texture stays low-contrast around paving and greenery. |
| 20x16 | `ground-opacity-24-20x16-1600x900-2026-10-29.png` | Same opacity and pattern scale at the largest footprint. |
| 20x16, 0.5x zoom and panned | `ground-opacity-24-lowzoom-pan-20x16-1600x900-2026-10-29.png` | Ground variation follows camera movement without a visible tile edge. |

Focused `test_backdrop_layer` passed 18 tests / 196 assertions; `git diff --check` is clean. The full suite was not run.

## Road direction arrows (2026-10-29)

Added opposing arrow markings in the two road lanes. Their vertices are defined in the road's world-plane coordinates, placed clear of the entrance crossing, and projected with the selected entrance side; this keeps the markings aligned when the store turns. The 12x10, 16x12, and 20x16 16:00 captures show the marks at each footprint, while the low-zoom/panned capture checks that they remain attached to the road during camera movement.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `road-arrows-12x10-1600x900-2026-10-29.png` | Both lane arrows fit between the entrance crossing and road edge. |
| 16x12 | `road-arrows-16x12-1600x900-2026-10-29.png` | Arrow scale and lane spacing remain readable at the medium footprint. |
| 20x16 | `road-arrows-20x16-1600x900-2026-10-29.png` | Opposing arrows remain within the wider store's entrance-side road. |
| 20x16, 0.5x zoom and panned | `road-arrows-lowzoom-20x16-1600x900-2026-10-29.png` | The road markings move with the projected world geometry. |

Focused `test_backdrop_layer` passed 20 tests / 229 assertions, including both arrow directions on all four store sides and arrow presence for all three store sizes. Full suite not run.

## Urban grove panel behind the roadside (2026-10-29)

The new generated `urban_grove_panel_v1` is a grouped transparent PNG of sakura, evergreen shrubs and flower beds. Its measured source ground-contact line runs from `(100, 680)` to `(2070, 680)` in a `2172x724` image. The transform maps those two endpoints to an 18m world-space line at z=0, beyond the outer sidewalk, using a rotation and uniform scale. The image is drawn before the road/paving mesh and far-wall occlusion, so roots and planter bases can be hidden by the foreground.

Actual Godot 4.7.2 runtime captures at 1600x900, 16:00:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `urban-grove-12x10-1600x900-2026-10-29.png` | Dense planting rises beyond the rear walls and continues beyond the short wall ends; the footprint uses a small register/shelf layout so exterior geometry is present. |
| 16x12 | `urban-grove-16x12-1600x900-2026-10-29.png` | Rear and outer side greenery connect to the ground plane; source scale remains fixed. |
| 20x16 | `urban-grove-20x16-1600x900-2026-10-29.png` | The long rear and roadside edges are covered, with remaining broad green field outside the planted strip. |
| 20x16, 0.8x zoom and pan | `urban-grove-panzoom-20x16-1600x900-2026-10-29.png` | The view shifts while the planting remains anchored to the projected world edge. |

Focused `test_backdrop_layer` passed 21 tests / 269 assertions at the time. That capture set is superseded for the 12x10 footprint by the compact-panel follow-up below. The broad green field remains a visual difference.

## Compact urban grove for short store edges (2026-10-29)

Added a second generated, grouped sakura/evergreen/flower panel for edges up to 12m. Its measured ground-contact endpoints `(358, 800)` and `(1544, 800)` in the `1825x862` image map to the exact wall-parallel edge endpoints at z=0 for 10m and 12m sides. Longer edges use the existing 18m source; for 20m edges, 1m low-shrub strips from the compact image complete both endpoints at its original uniform pixel scale. All panels remain behind the store and road. Runtime captures show that the former conspicuous short-store overhang is gone and the 20m edge is joined at both ends without stretching either image.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `compact-grove-12x10-1600x900-2026-10-29.png` | Compact group reaches the short back-wall endpoints without the former 18m strip extending past them. |
| 16x12 | `compact-grove-16x12-1600x900-2026-10-29.png` | The 12m edge uses the compact source and planting remains continuous at the wall ends. |
| 20x16 | `urban-grove-endcaps-20x16-1600x900-2026-10-29.png` | Two 1m compact shrub strips join the long panel to the 20m edge endpoints. |
| 20x16, 0.8x zoom and pan | `urban-grove-endcaps-panzoom-20x16-1600x900-2026-10-29.png` | Both end strips and the long panel stay anchored during the view move. |

Focused `test_backdrop_layer` passed 21 tests / 295 assertions, covering source texture dimensions, exact projected root endpoints and cap joins on all four sides at the three footprints, uniform source scale, and camera pan for both end strips. The full suite was not run.

## Static road vehicle (2026-10-29)

Added one compact car on the exterior road, oriented along the entrance-side street and anchored at the frontage quarter farthest from the doorway. It clears the pedestrian crossing and remains decorative. Runtime captures at 12x10, 16x12, 20x16, and a panned/zoomed 20x16 view confirm the vehicle stays on the road and in frame. On the 12x10 footprint, the road is still visually crowded by the existing parked car and the new road vehicle.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `urban-grove-road-car-12x10-1600x900-2026-10-29.png` | Both cars remain visible; exterior planting extends past the short wall ends. |
| 16x12 | `urban-grove-road-car-16x12-1600x900-2026-10-29.png` | The road vehicle is clear of the crossing, with a dense planted perimeter. |
| 20x16 | `urban-grove-road-car-20x16-1600x900-2026-10-29.png` | The road car and parked car are both within the wider roadside scene. |
| 20x16, 0.8x zoom and pan | `urban-grove-road-car-panzoom-20x16-1600x900-2026-10-29.png` | The vehicle stays anchored to the road while the camera moves. |

Focused `test_store_decor` passed 21 tests / 371 assertions, including each supported footprint and entrance orientation. `git diff --check` is clean. Full suite not run.

## U-shaped grove on non-road sides (2026-10-29)

Extended the grouped grove from the single entrance-facing edge to the other three store sides. This leaves the entrance road and crossing open. These sides have no public road, so the grove base now sits at 2.43m from the wall: just beyond the 2m paved ring and kerb, with wall/paving layers hiding the roots. The compact 10m/12m panel and the 18m panel with 20m endcaps retain their measured z=0 anchors and uniform image scaling. The generated width/height never change with camera movement; transforms are rebuilt from world coordinates.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `perimeter-u-close-12x10-1600x900-2026-10-29.png` | Trees rise above the rear and side walls; the entrance-side road stays clear. |
| 16x12 | `perimeter-u-close-16x12-1600x900-2026-10-29.png` | Planting joins around the far corners and remains behind the store walls. |
| 20x16 | `perimeter-u-close-20x16-1600x900-2026-10-29.png` | Long rear and side bands close the U, with the 20m edge endcaps in place. |
| 20x16, 0.8x zoom and pan | `perimeter-u-panzoom-20x16-1600x900-2026-10-29.png` | The three bands stay attached to their world-space edges as the camera moves. |

Focused `test_backdrop_layer` passed 22 tests / 315 assertions at the time, including all four entrance orientations and the then-current 20m cap joins. That cap implementation and capture set were replaced by the three full-panel setup documented below. Full suite not run.

## Green-forward grove panels, ground-anchored at all three lengths (2026-10-29)

Replaced the pink-heavy/cropped-edge variation with three generated green-forward panels selected by world edge length: a 12m compact panel, an 18m panel for intermediate edges, and a single 20m panorama. Each panel is uniformly scaled from its authored baseline; its ground contact is placed at z=0, 2.43m outside the wall. Wall and paving draw over the roots and lower stems. The rear V branches remain independently fitted and endpoint-checked. No source panel is stretched or cropped into end caps.

Actual Godot 4.7.2 captures at 1600x900, 16:00, stocked layout:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `green-grove-v1-stocked-12x10-1600x900-2026-10-29.png` | Compact source fits the short edges; wall hides the lower planting while tree crowns rise above it. |
| 16x12 | `green-grove-v1-stocked-16x12-1600x900-2026-10-29.png` | The 18m source covers the intermediate edge with the same world-space tree height. |
| 20x16 | `green-grove-v1-stocked-20x16-1600x900-2026-10-29.png` | Dedicated 20m source reaches each wall endpoint without isolated cropped end pieces. |
| 20x16, zoomed and panned | `green-grove-v1-stocked-pan-20x16-1600x900-2026-10-29.png` | Ground anchors and wall occlusion remain attached as the camera moves. |

The three rear/side source baselines are separately asserted against the projected endpoints for all supported footprints. Focused `test_backdrop_layer` passed 22 tests / 299 assertions. The full suite was not run. The low-opacity ground tile is visible in these same captures; its close-up motif repetition and the remaining broad open field are recorded in `REMAINING_DIFFERENCES.md`.

## Outer ground texture refinement (2026-10-29)

Replaced the sparse fine-fleck ground overlay with a generated low-clover, leaf, and small-flower texture at the same camera-following screen-space tile scale. It remains behind the store scenery and geometry. A 36% opacity trial made the repeated motifs too prominent, so the integrated candidate is 24% opacity.

Actual Godot 4.7.2 runtime captures at 1600x900, 16:00, whole-store camera:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `outer-ground-v2-stocked-12x10-1600x900-2026-10-29.png` | Stocked fixtures remain visible; ground variation stays subdued around the parking area and planting. |
| 16x12 | `outer-ground-v2-stocked-16x12-1600x900-2026-10-29.png` | The overlay follows the viewport while the stocked store and exterior remain in frame. |
| 20x16 | `outer-ground-v2-stocked-20x16-1600x900-2026-10-29.png` | The broader field gains low vegetation and sparse blossoms; the perimeter grove stays distinct. |
| 20x16, zoomed and panned | `outer-ground-v2-stocked-pan-20x16-1600x900-2026-10-29.png` | The texture phase follows the camera movement without a strong boundary. |

The tile source has mean opposite-edge RGB differences of 20.50 horizontally and 18.23 vertically. At 24% the join is subdued in the runtime captures, although the motif repeats under close inspection. The flat open ground still differs from the target's richer surrounding street and planting.

## Continuous entrance parking and sidewalk panels (2026-10-29)

Generated panels now cover the complete entrance-side ground surface without the former 1m paver grid. The 10m, 12m, 16m, and 20m variants contain a continuous sidewalk/apron, parking bays, wheel stops, and road surface. Each uses a measured store-side sidewalk edge as its source anchor; code maps that line to the selected world-space wall edge with rotation and uniform scale. The image contains no fixed crosswalk, so the live entrance crossing remains aligned to the active door.

Actual Godot 4.7.2 runtime captures at 1600x900, 12:00:

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `area-a-continuous-v1-12x10-1600x900-2026-10-29.png` | The compact panel follows the south-facing entrance edge; parking paint stays clear of the store interior. |
| 16x12 | `area-a-continuous-v1-16x12-1600x900-2026-10-29.png` | The medium panel reaches both wall ends with a continuous parking/sidewalk band. |
| 20x16 | `area-a-continuous-v1-20x16-1600x900-2026-10-29.png` | The 20m panel covers the long facade without a visible edge gap. |
| 20x16, 1.15x zoom and pan | `area-a-continuous-v1-pan-zoom-20x16-1600x900-2026-10-29.png` | Parking lines and wheel stops remain attached to the projected storefront edge. |
| 20x16, east entrance | `area-a-continuous-v1-20x16-east-entrance-1600x900-2026-10-29.png` | The road panel pivots to the east wall; the three-side grove remains on the other walls. |

The focused `test_backdrop_layer` suite passed 22 tests / 327 assertions, including all four entrance-side mappings, uniform scale, camera pan, and the continuous paving surface. Only this focused suite was run; the full suite was not run.

## Remaining differences from the target mockup

- The target has a fully enclosed, highly reflective convenience-store facade. This game keeps its low cut-away front so the interior and existing store interaction remain visible; automatic sliding-door animation, brand signage on the long fascia and denser reflections are not present.
- The ground artwork has asphalt, parking bays, wheel stops, curb, sidewalk paving, and grouped planting. The new 24%-opacity ground tile adds low-clover, leaf, and flower variation, but a broad open field remains and the scene still lacks the target's full-depth flower beds and surrounding street structures.
- The target shows a busier street scene, multiple vehicles, dense flowers, street furniture, and storefront posters. Current runtime has one parked car plus one static road car, with fewer visible exterior details.
- Store shelves, people, and product presentation differ substantially from the target and were outside this exterior change.

The side-by-side comparison is `target-vs-after-20x16.png`; it uses a different store aspect ratio from the supplied mockup and is not a pixel-matched image test. These captures establish placement and runtime appearance, not final art approval. The user's final visual review is still required.

## Dense grouped perimeter grove candidate v2 (2026-10-29)

Two image-generation subagents created grouped planting candidates. The first pair was rejected: one had an opaque checkerboard baked into its pixels; the other had strong bright color spill around the transparent edge. After more constrained regeneration, one alpha PNG was installed as a runtime candidate. Its isolated edge still has some bright pixels, but the in-game captures do not show a prominent halo at whole-scene size.

The new panorama replaces the compact, intermediate and 20m sources with one grouped image. It uses the same (100,700)-(2070,700) ground-contact baseline for edge-specific 12m, 18m and 20m uniform scales, rooted at z=0 and 2.43m outside the wall. The opaque wall and paving layers still cover the roots and lower stems. No panel is non-uniformly stretched or cropped into connectors.

Actual Godot 4.7.2 captures at 1600x900, 16:00, frozen:

| Footprint/view | Capture | Observation |
|---|---|---|
| 12x10 | `grove-density-candidate-v2-12x10-1600x900-2026-10-29.png` | Denser tree crowns and flower clusters rise behind both rear walls; lower planting is occluded. |
| 16x12 | `grove-density-candidate-v2-16x12-1600x900-2026-10-29.png` | Same panorama scales to the default footprint; both rear branches remain continuous. |
| 20x16 | `grove-density-candidate-v2-20x16-1600x900-2026-10-29.png` | Long branch reaches the far endpoints; planting density improves behind the roofline. |
| 20x16, panned and zoomed | `grove-density-candidate-v2-20x16-pan-1600x900-2026-10-29.png` | The image follows the world projection during camera movement without a gap at the wall edge. |

Focused `test_backdrop_layer` passed 23 tests / 333 assertions, including the independent rear branches, endpoint anchors, upright trunks and camera pan. Focused `test_shell_camera_input` passed 10 tests / 96 assertions, including pan/zoom, selection after movement and UI click blocking. The new panel is still a runtime candidate, not user-approved; the broad open ground, overall scene style, seasonal rendering and performance gate remain open.

## Detailed grouped grove candidate v1 (2026-10-29)

An image-generation subagent produced a fuller illustrated planting band with layered shrubs, small blossoms, taller tree crowns and a continuous soil/root edge. It replaces the dense panorama as the runtime candidate. The authored 2172x724 image keeps the measured (100,700)-(2070,700) ground-contact baseline; runtime places that line at z=0, 2.43m behind the store wall. Roots, lower stems and soil may sit behind the opaque wall/paving; each rear and side edge retains its own world-space endpoints and uniform edge-specific scale.

Actual Godot 4.7.2 captures at 1600x900, 16:00, frozen:

| Footprint/view | Capture | Observation |
|---|---|---|
| 12x10 | `grove-detailed-candidate-v1-12x10-1600x900-2026-10-29.png` | Grouped flower beds and shrubs continue behind the short walls; the wall masks the lower edge. |
| 16x12 | `grove-detailed-candidate-v1-16x12-1600x900-2026-10-29.png` | Same baseline and plant scale fit the intermediate footprint. |
| 20x16 | `grove-detailed-candidate-v1-20x16-1600x900-2026-10-29.png` | The full edge reaches its endpoints with planted scenery behind the wall. |
| 20x16, panned and zoomed | `grove-detailed-candidate-v1-20x16-pan-1600x900-2026-10-29.png` | World-ground anchors and wall masking stay registered while the view moves. |

Focused `test_backdrop_layer` passed 23 tests / 333 assertions. A focused renderer benchmark at 1920x1080, 16x12, 20 fixtures and 30 customers over 600 frames measured median 16.41 FPS at x1, 14.37 at x2 and 10.81 at x4; x4 median frame time was 92.51ms. The performance gate remains open. Full suite not run. The candidate has not received final visual approval; surrounding broad ground remains simpler than the reference.

## Current focused operation rerun and generated-candidate screening (2026-10-29)

The current runtime branch passed `test_shell_camera_input`: 10 tests / 96 assertions, 0 failures. This exercises canopy cutaway, fit, pan/zoom, tile selection after camera movement, cancel keys, UI input blocking, and selection inspection. No full suite was run.

Four newly generated background candidates were screened before integration. The two grouped alpha panoramas had conspicuous green/yellow or red edge fringe; an opaque full-scene underlay had a top-down rather than game-matched view; and the edited panorama baked a checkerboard into the canvas. They were rejected and not copied into the runtime asset directory. The existing detailed grove remains the active candidate. The broad outer ground still needs a camera-matched continuous scene asset; the rejected images do not close that gap.
