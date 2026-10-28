# Exterior vegetation fit review — 2026-10-28

## Scope

Reviewed the generated rear V-shaped planting bed, full-length right-side planted strip, and combined entrance/parking apron in the actual Godot game at 1600×900. Captures use whole-store fit and the sample store layout. The 12×10 and 20×16 layouts use the game's small and large size controls; 16×12 is the default layout.

## Changes

- Replaced the rear planting image with a generated tall-tree V asset. Its two ground edges were measured and independently corrected to the game's −0.5 and +0.5 isometric slopes. The processing preserves vertical trunks and applies only a small per-wing vertical shear; runtime placement uses uniform scale.
- Anchored the V bed's ground contact to world `(-0.95, -0.95, 0)`, behind the far store corner. The runtime transform is based on that ground point, not the image top/bottom or wall top.
- Repainted opaque far-wall surfaces after the backdrop vegetation, so planter edges and roots disappear naturally behind the wall while tree crowns remain visible above it.
- Changed the side planting run from half of the relevant store edge to the full edge plus a 1 m overhang. Its length uses the relevant world side (height for east, width for south).
- Added a generated combined entrance/parking apron with parking bays, road edge, and planted borders; it has no crossing at the store entrance.

## Game captures

| Layout | Capture | Observation |
|---|---|---|
| 12×10 | [store-12x10.png](store-12x10.png) | V foliage continues behind both far walls; lower planting is masked at the wall. Right-side landscape reaches beyond the store end. |
| 16×12 | [store-16x12.png](store-16x12.png) | Same ground anchor and occlusion; both V branches remain continuous. |
| 20×16 | [store-20x16.png](store-20x16.png) | Both branches cover the longer far edges; the common uniform scale leaves extra scenery past the shorter branch endpoint rather than a gap. |
| 20×16, camera panned | [store-20x16-pan.png](store-20x16-pan.png) | Foliage, wall mask, and side planting move together with the world camera. |

## Remaining differences

- The generated flowers, stone edging, lighting, and foliage density are more painterly and less photo-detailed than the target mockup.
- Since the V is one continuous image and must retain one uniform scale, the shorter branch can extend beyond its wall endpoint on rectangular store sizes. This intentionally avoids anisotropic stretching and uncovered wall ends; the extra ends should be reviewed by the user.
- The right-side strip reaches the wall endpoint but remains visually sparser and more repetitive than the reference mockup; it would benefit from a denser, richer one-piece U-shaped asset.
- The entrance apron and parking details are a painterly combined background rather than individually interactive props. Static spring vegetation has no season variants. Existing temporary in-store potted plants remain separate gameplay props and were not changed.

## Verification

- Targeted `test_backdrop_layer.gd`: 12 tests, 48 assertions, 0 failures.
- GDScript parse checks passed for `backdrop_layer.gd`, `wall_layer.gd`, `store_world.gd`, and the focused unit test.
- No full test suite was run.
