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

## Remaining differences from the target mockup

- The target has a fully enclosed, highly reflective convenience-store facade. This game keeps its low cut-away front so the interior and existing store interaction remain visible; automatic sliding-door animation and denser reflections are not present.
- The ground artwork now has asphalt, parking bays, wheel stops, curb, sidewalk paving, and planting. Its painterly realism is still stronger than the game's older sprites, and the surrounding world beyond the road remains mostly a flat green field.
- The target shows a busier street scene, multiple vehicles, dense flowers, street furniture, and storefront posters. Current runtime has one parked car and fewer visible exterior details.
- Store shelves, people, and product presentation differ substantially from the target and were outside this exterior change.

The side-by-side comparison is `target-vs-after-20x16.png`; it uses a different store aspect ratio from the supplied mockup and is not a pixel-matched image test. These captures establish placement and runtime appearance, not final art approval. The user's final visual review is still required.
