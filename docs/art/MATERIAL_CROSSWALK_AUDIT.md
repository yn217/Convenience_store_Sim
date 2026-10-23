# Fixture material crosswalk audit (Issue #22)

`tools/art/validate_material_crosswalk.py` checks that every material candidate is tied to a unique `fixture_type_id`, has exactly two review variants, and that all source/variant paths exist.

The audit preserves `source-only candidate set; not runtime-approved`. It does not claim four-direction fixture renders, footprint/anchor validation, or Godot integration.

`MATERIAL_CANDIDATE_MANIFEST.json` records each of the six variants with an explicit `variant_id`, derived review `visual_id`, SHA-256, and `runtime_approved: false`. The scope is intentionally limited to the three baseline material families; seven other fixture IDs remain unregistered and are not treated as complete.
