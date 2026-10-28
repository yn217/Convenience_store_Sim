# Area A / storefront follow-up QA (2026-10-29)

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

Added a second generated, grouped sakura/evergreen/flower panel for edges up to 12m. Its measured ground-contact endpoints `(358, 800)` and `(1544, 800)` in the `1825x862` image map to the exact wall-parallel edge endpoints at z=0 for 10m and 12m sides. The panel switches to the existing 18m source on longer edges. Both are rendered behind the store and road; their image proportions remain uniform. Runtime captures show that the former conspicuous fixed-length overhang at 12x10 is removed; on 20x16 the long panel still intentionally overlaps past the 18m root span to keep coverage.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `compact-grove-12x10-1600x900-2026-10-29.png` | Compact group reaches the short back-wall endpoints without the former 18m strip extending past them. |
| 16x12 | `compact-grove-16x12-1600x900-2026-10-29.png` | The 12m edge uses the compact source and planting remains continuous at the wall ends. |
| 20x16 | `compact-grove-20x16-1600x900-2026-10-29.png` | The long generated source remains in use; the roadside planting continues past the far-wall silhouette. |
| 20x16, 0.8x zoom and pan | `compact-grove-panzoom-20x16-1600x900-2026-10-29.png` | The long panel stays at its world ground anchors as the view moves. |

Focused `test_backdrop_layer` passed 21 tests / 271 assertions, covering source texture dimensions, exact projected root endpoints on all four sides at the three footprints, uniform source scale, and camera pan. The full suite was not run.

## Static road vehicle (2026-10-29)

Added one compact car on the exterior road, oriented along the entrance-side street and anchored at the frontage quarter farthest from the doorway. It clears the pedestrian crossing and remains decorative. Runtime captures at 12x10, 16x12, 20x16, and a panned/zoomed 20x16 view confirm the vehicle stays on the road and in frame. On the 12x10 footprint, the road is still visually crowded by the existing parked car and the new road vehicle.

| Store size / view | Capture | Observation |
|---|---|---|
| 12x10 | `urban-grove-road-car-12x10-1600x900-2026-10-29.png` | Both cars remain visible; exterior planting extends past the short wall ends. |
| 16x12 | `urban-grove-road-car-16x12-1600x900-2026-10-29.png` | The road vehicle is clear of the crossing, with a dense planted perimeter. |
| 20x16 | `urban-grove-road-car-20x16-1600x900-2026-10-29.png` | The road car and parked car are both within the wider roadside scene. |
| 20x16, 0.8x zoom and pan | `urban-grove-road-car-panzoom-20x16-1600x900-2026-10-29.png` | The vehicle stays anchored to the road while the camera moves. |

Focused `test_store_decor` passed 21 tests / 371 assertions, including each supported footprint and entrance orientation. `git diff --check` is clean. Full suite not run.

## Remaining differences from the target mockup

- The target has a fully enclosed, highly reflective convenience-store facade. This game keeps its low cut-away front so the interior and existing store interaction remain visible; automatic sliding-door animation, brand signage on the long fascia and denser reflections are not present.
- The ground artwork has asphalt, parking bays, wheel stops, curb, sidewalk paving, and grouped planting. The low-opacity v2 texture adds fine variation, but the scene still lacks full-depth flower beds and street structures.
- The target shows a busier street scene, multiple vehicles, dense flowers, street furniture, and storefront posters. Current runtime has one parked car plus one static road car, with fewer visible exterior details.
- Store shelves, people, and product presentation differ substantially from the target and were outside this exterior change.

The side-by-side comparison is `target-vs-after-20x16.png`; it uses a different store aspect ratio from the supplied mockup and is not a pixel-matched image test. These captures establish placement and runtime appearance, not final art approval. The user's final visual review is still required.
