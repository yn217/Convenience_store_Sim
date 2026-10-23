# Package LOD candidates (Issue #12)

The normalized transparent package cutouts now have reproducible review-only LODs at 0.5x and 0.25x. Generate them with `tools/art/build_package_lods.py` and validate them with `tools/art/validate_package_lods.py`.

The manifest is `assets/source/textures/packages/candidates/lod/LOD_MANIFEST.json`. These files are not connected to runtime product definitions or Godot; visual selection, readability at zoom 0.5/1/2, and runtime wiring remain open work.

The review sheet is `docs/art/package_lod_comparison.png` and can be regenerated with `tools/art/build_package_lod_preview.py`.

`VISUAL_LOD_MANIFEST.json` maps the six existing review visual IDs (`rice`, `drink`, and `noodle`) to their source cutout and LOD paths. It is deliberately review-only; the existing procedural visual IDs remain the fallback until human mark review and `iso2x_v1` integration are complete.
