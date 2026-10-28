# Mockup comparison: remaining exterior work

Reference: user-supplied `image-1792819026698.webp` (16:28) and the current Godot 4.7.2 20x16 capture at 16:00, `daylight-ground-v2-20x16-1600x900-2026-10-29.png`. The paired regional overview is `regions-target-vs-daylight-20x16-2026-10-29.png`; full-frame comparison is `mockup-daylight-comparison-20x16-2026-10-29.png`. Crops are selected by visual subject, not pixel registration: the mockup and game use different camera framing and store contents.

| Region | Target vs current | Remaining 2D work and world placement | Priority |
|---|---|---|---|
| Storefront | Target has a long, bright, branded fascia over tall glazed panes. The game has a blue/white band, cut-away glass facade and a larger fictional store-name label; target logo art and denser framing remain absent. | Keep the name centered on its wall plane; create short repeatable fascia modules and additional window framing only where they preserve transparent shop visibility and the entrance opening. | P1 |
| Entrance | Target has framed automatic glass doors, a dark entrance mat and nearby promotion. Game has an open entrance with a mat and does not animate sliding leaves. | Add door leaves as independently animated 2D pieces only if they leave the existing customer path and click-through behavior intact; place posters and mat from wall/world anchors. | P2 |
| Parking | Both show asphalt, stalls and wheel stops. Target has richer surface detail, painted arrows and more varied car/curb details; game markings are legible but simpler. | Add low-contrast asphalt variation under existing stall/stop geometry; keep markings in world space with the entrance frontage. | P2 |
| Road | Target shows a broader street, directional arrows and a moving/parked vehicle. Game now has opposing lane arrows, lane marks, edge line and crossing; it still has fewer traffic cues. | Add a second static vehicle and more curb/road detail as separate world-anchored elements, outside the store interaction footprint. | P2 |
| Sidewalk | Target's brighter paving, curb and planting borders have varied stone detail. Game has tiled paving with a continuous curb and generated sidewalk strip. | Improve the existing strip with restrained tile/paving variation while preserving measured endpoints and its camera-follow transform. | P2 |
| Planting | Target surrounds the building with dense layered trees and flowering beds. Game has grouped tall rear trees and roadside beds, but a large green field remains. | Extend background scenery as continuous grouped 2D panels. Keep roots on the exterior ground behind walls; avoid individual tree placement and do not stretch source art. | P1 |
| Pole sign | Target has a tall stacked sign with a blue store panel and separate service panels. Game now has separate tobacco, alcohol, and ATM color panels with code-rendered labels; the fictional store mark and target-like sign material/detail remain different. | Refine the store mark and sign surface detail while keeping the service rows readable at full-scene scale. | P2 |
| Outdoor props | Target includes bike racks/bicycles, benches, banners, planters, bins, vending machines and an open board. Game contains most base prop classes but fewer planters, banners and promotional items. | Add the missing grouped props as independent sprites; use existing prop placement and occlusion layers so they remain clickable where appropriate. | P2 |
| Side wall and HVAC | Target's gray side wall carries vents, conduit, wall lights, stacked HVAC units and rear fencing. Game has a plain wall and two HVAC units. | Add modular wall panels, conduit, vents and a short fence around existing HVAC anchors; preserve the opaque far-wall order used for plant-root occlusion. | P3 |
| Lighting | Target uses bright daylight, warm interior light and visible outdoor fixtures. Game now has a 16:00 daylight palette and localized lamp/window spill; the broader scene remains less luminous. | Tune only presentation-layer fills and existing light spill after the fixture and wall art pass; do not alter simulation time or economy behavior. | P3 |

## Current-cycle result

- The generated `ground_texture_seamless_v2` is now the 24%-opacity exterior overlay. It follows the camera tile phase and was captured at 12x10, 16x12, 20x16, and 20x16 with pan/zoom. The stronger flecks add surface variation; they do not close the broad green-field difference.
- The near-side fascia label was enlarged from 24px to 32px and its white backing extended from 4.2m to 5.2m in wall-plane units. The label remains world-anchored and centered; captures at all three supported sizes show no clipping.
- The entrance-side road now has opposing directional arrows centered in its two lanes. Their geometry is built in road-plane metres, shifts with the entrance side, and remains in the static projected road mesh.
- A generated long fascia strip was not integrated because it is one oversized perspective piece with bright edge fringing and does not fit the game's modular wall construction. A second requested module still arrived as a 1774x887 long strip, so it also remains a candidate only.
- A 16x12-reference scale for rear planting was rejected because it failed to cover the 20x16 right wall endpoint. The fixed scale remains based on 20x16, leaving extra planted overhang at 12x10.
- Focused checks: backdrop 18 tests / 196 assertions, camera/input scene 10 / 96, storefront decor 19 / 298; all passed. No full suite was run.

## Ordering

1. Generate and integrate a genuinely modular storefront trim/logo unit with the correct projection and aligned ends.
2. Improve the road/parking and sidewalk materials without moving existing world geometry.
3. Fill the remaining green field and increase service-panel/prop detail.
4. Recompare at daylight with matching camera scale; ask for visual approval before marking the exterior goal complete.
