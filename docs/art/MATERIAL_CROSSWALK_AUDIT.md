# Fixture material crosswalk audit (Issue #22)

`tools/art/validate_material_crosswalk.py` checks that every material candidate is tied to a unique `fixture_type_id`, has exactly two review variants, and that all source/variant paths exist.

The audit preserves `source-only candidate set; not runtime-approved`. It does not claim four-direction fixture renders, footprint/anchor validation, or Godot integration.
