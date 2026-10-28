# Exterior vegetation fit review — 2026-10-28

## Scope

Reviewed the generated rear V-shaped planting bed, full-length right-side planted strip, combined entrance/parking apron, and transparent full-height storefront glazing in the actual Godot game. The three store sizes use whole-store fit at 1600×900; additional captures cover 1280×720 at low zoom, 1920×1080 at high zoom, a 20×16 camera pan, and build placement preview.

## Changes

- Replaced the rear planting image with a generated tall-tree V asset. Its two ground edges were measured and independently corrected to the game's −0.5 and +0.5 isometric slopes. The processing preserves vertical trunks and applies only a small per-wing vertical shear; runtime placement uses uniform scale.
- Anchored the V bed's ground contact to world `(-0.95, -0.95, 0)`, behind the far store corner. The runtime transform is based on that ground point, not the image top/bottom or wall top.
- Repainted opaque far-wall surfaces after the backdrop vegetation, so planter edges and roots disappear naturally behind the wall while tree crowns remain visible above it.
- Changed the side planting run from half of the relevant store edge to the full edge plus a 1 m overhang. Its length uses the relevant world side (height for east, width for south).
- Regenerated the rear V artwork with denser layered trees, shrubs, and flowers. Independently measured both ground edges and calibrated them to −0.5/+0.5 while retaining a uniform runtime scale.
- Replaced the side-strip image with a taller grouped tree/shrub/flower asset. Its ground edge was measured and calibrated to the projection slope; runtime uses its measured root edge as the world anchor and uniform scale.
- Added a subtle, transparent full-height pane and reflection overlay to closed frontage spans. It follows the wall's world geometry, leaves the entrance open, and preserves the visible interior and build preview.
- Added a generated combined entrance/parking apron with parking bays, road edge, and planted borders; it has no crossing at the store entrance.

## Game captures

| Layout | Capture | Observation |
|---|---|---|
| 12×10 | [store-12x10.png](store-12x10.png) | New V and taller side foliage remain connected behind the walls; the right strip reaches past the corner. |
| 16×12 | [store-16x12.png](store-16x12.png) | Both calibrated V branches continue behind the walls; facade glazing remains see-through. |
| 20×16 | [store-20x16.png](store-20x16.png) | Longer walls remain covered and the right strip extends beyond the far corner. |
| 20×16, camera panned | [store-20x16-pan.png](store-20x16-pan.png) | Store, foliage, and wall occlusion move together with the camera. |
| 1280×720, ×0.8 zoom | [store-1280-lowzoom.png](store-1280-lowzoom.png) | Exterior remains readable at lower zoom; plants and wall edges stay aligned. |
| 1920×1080, ×1.2 zoom | [store-1920-highzoom.png](store-1920-highzoom.png) | At close zoom, walls still mask the root line and glazing remains transparent. |
| Build placement preview | [build-preview.png](build-preview.png) | Translucent panes do not cover the placement highlight or obstruct the interior view. |

## Remaining differences

- The generated flowers, stone edging, lighting, and foliage density are more painterly and less photo-detailed than the target mockup. The side strip has taller crowns now, but remains a single narrow band rather than the target's broad layered planting.
- Since the V is one continuous image and must retain one uniform scale, the shorter branch can extend beyond its wall endpoint on rectangular store sizes. This intentionally avoids anisotropic stretching and uncovered wall ends; the extra ends should be reviewed by the user.
- The right-side strip reaches the wall endpoint with a 1 m world overhang, but endpoint and continuity were visually checked in game rather than exhaustively sampled for every entrance orientation. A richer one-piece U asset would better match the layered reference planting.
- Full-height glazing is a transparent procedural overlay; it does not yet reproduce the mockup's detailed door framing, interior reflections, signage, or photographic lighting.
- The entrance apron and parking details are a painterly combined background rather than individually interactive props. Static spring vegetation has no season variants. Existing temporary in-store potted plants remain separate gameplay props and were not changed.

## Verification

- Targeted `test_backdrop_layer.gd`: 12 tests, 50 assertions, 0 failures.
- Targeted `test_store_decor.gd`: 18 tests, 375 assertions, 0 failures.
- GDScript parse checks passed for `backdrop_layer.gd`, `wall_layer.gd`, `store_world.gd`, and the focused unit test.
- No full test suite was run.
