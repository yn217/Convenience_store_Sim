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

`roots-pan-zoom-16x12-2026-10-29.png` verifies that the ground anchor follows a translated, zoomed camera. The new captures show the tree and shrub bases staying behind the far walls while the taller canopies remain visible above them. Both V branches are tested independently; uniform scaling is set by the longer required run so neither wall endpoint opens a gap, and the shorter branch's extra art remains behind the wall rather than being cropped or stretched.

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

## Remaining differences from the target mockup

- The target has a fully enclosed, highly reflective convenience-store facade. This game keeps its low cut-away front so the interior and existing store interaction remain visible; automatic sliding-door animation and denser reflections are not present.
- The ground artwork now has asphalt, parking bays, wheel stops, curb, sidewalk paving, and planting. Its painterly realism is still stronger than the game's older sprites, and the surrounding world beyond the road remains mostly a flat green field.
- The target shows a busier street scene, multiple vehicles, dense flowers, street furniture, and storefront posters. Current runtime has one parked car and fewer visible exterior details.
- Store shelves, people, and product presentation differ substantially from the target and were outside this exterior change.

The side-by-side comparison is `target-vs-after-20x16.png`; it uses a different store aspect ratio from the supplied mockup and is not a pixel-matched image test. These captures establish placement and runtime appearance, not final art approval. The user's final visual review is still required.
