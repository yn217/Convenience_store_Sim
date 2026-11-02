# Issue #231 — aspect-preserving projection fix (2026-11-02)

## Finding and change

The old axis audit resized the 1774×887 background to 896×512, changing its 2:1 aspect ratio to 1.75:1. That introduced 14.3% vertical stretch and produced a false reading near +30°. The runtime then applied an unnecessary 0.866 depth factor, deforming a source that was already close to the store camera. The factor is removed; the image now uses equal X/Y scale. The minimum scale is 1.6 to retain margin at zoom 0.5 for the tested ±160/±120px camera pan.

The aspect-preserving Canny/Hough screen places the active v6 source angle families at −26.38° and +25.80°, against the store target of ±26.565°. It includes roofs and foliage as well as ground edges, so this is a screening measurement, not ground-only proof. The two parallel-generated images remain rejected: both leave broad empty clearings and their measured angle pair is less balanced. Hashes and measurement details are in [`axis-screening.json`](issue-231-exact-axis-qa-2026-11-02/axis-screening.json).

## Actual-game comparison

These UI-free Godot 4.7.2 world captures use the runtime v6 texture, equal-axis transform, daylight, and 1920×1080 viewport:

- 12×10: `issue-231-exact-axis-qa-2026-11-02/runtime-v6-uniform-12x10-world-only-1920x1080.png`
- 16×12: `issue-231-exact-axis-qa-2026-11-02/runtime-v6-uniform-16x12-world-only-1920x1080.png`
- 20×16: `issue-231-exact-axis-qa-2026-11-02/runtime-v6-uniform-20x16-world-only-1920x1080.png`
- 20×16 at zoom 0.5 and pan +160/−120: `issue-231-exact-axis-qa-2026-11-02/runtime-v6-uniform-20x16-panzoom05-world-only-1920x1080.png`
- Contact sheet: `issue-231-exact-axis-qa-2026-11-02/runtime-v6-uniform-world-only-contact.png`

All four images retain the backdrop through the camera movement; the detached horizontal planting strip is absent. The source remains more painterly and detailed than the game store, and the frontage proportions and exposed paving still need review.

## Focused checks

- `test_backdrop_layer.gd`: 26 tests, 377 assertions, passed.
- `test_shell_camera_input.gd`: 10 tests, 96 assertions, passed.
- `test_iso_projection.gd`: 14 tests, 4,512 assertions, passed.
- `git diff --check`: passed apart from line-ending notices. No full test suite was run.

Issue #231 remains open and PR #166 remains Draft pending user visual review.
