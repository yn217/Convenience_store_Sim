# Onigiri refrigerated display — ImageGen review candidate

- Asset ID: `shelf_onigiri_refrigerated_FULL_v1`
- Review only: `runtime_approved: false`
- Status: `review_candidate_pending_projection_and_scale`; raw output misses the minimum alpha margin.
- Source: Codex built-in ImageGen, generated 2026-11-01; background-only transparency correction was applied by ImageGen. Original generated files remain outside the repository in the Codex generated-images directory.
- Main image: `source_original.png` (1254×1254 RGBA, unchanged after the transparency correction)
- SHA-256: `685a8df317540a71272528932c1dbb598591215f8d8b79642d78a26ea66e1fa5`
- `alpha_preview.png` composites the original over a checkerboard for inspection.

## Visual review

- Integrated fixture and merchandise: PASS. Four refrigerated tiers contain packaged onigiri with a small selection of sushi; each item sits within a guarded shelf lane.
- Category/readability: PASS at source resolution; triangular rice-ball packs and nori are visible. Labels are decorative and are not expected to be legible at runtime.
- Box-like product extrusion: PASS. Packs read as thin wrappers/products, not repeated thick cuboids.
- Fixture completeness: PASS for an open-front refrigerated case with side glazing, shelf guards, light rail and refrigeration plinth.
- Raw alpha margin: FAIL. For alpha >8, margins L/T/R/B are 6.38% / 10.29% / 6.62% / 2.55%; minimum required is 12%. Edge alpha maxima (top/bottom/left/right): 0/1/1/0. The near-bottom antialias fringe makes the original unsuitable without a canvas/anchor correction.
- Isometric angle, axis orientation, world dimensions, 1×2 footprint, anchor, and Godot display-scale fit: NOT VERIFIED. The wide refrigerated case may not match the target fixture footprint.
- Independent art review: pending; this is not runtime-approved.

## Files

- `source_original.png`: original transparent-background ImageGen result.
- `alpha_preview.png`: alpha inspection.
- `prompt_record.txt`: prompts and reference-image roles.
- `qa.json`: machine-readable checks and measurements.
