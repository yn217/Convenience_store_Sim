# Individual candidate crops

This stacked change depends on PR #65. It preserves each generated comparison
board and adds lossless, deterministic left/right candidate crops for the next
review stage.

- 12 individual PNG candidates: 3 SKU families plus 3 fixture-material
  families, two variants each.
- `assets/source/textures/CANDIDATE_CROPS.json` records the source, crop box,
  output size, and method.
- `docs/art/package_material_individual_candidates.png` is the review sheet.
- `tools/art/split_comparison_boards.py` reproduces all crops and the sheet.

The crop is not an approval gate. The generated boards include deliberately
generic marks and may contain visual details requiring manual trademark/text
review. These candidates remain source-only and are not used by the runtime.
The next step is to select one concept per family, correct any marks, remove
backgrounds where required, and render through the common `iso2x_v1` pipeline.

No dimensions, SKU IDs, stock calculations, fixture footprints, or Godot files
are changed.
