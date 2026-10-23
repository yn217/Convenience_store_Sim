# Package LOD candidates (Issue #12)

The normalized transparent package cutouts now have reproducible review-only LODs at 0.5x and 0.25x. Generate them with `tools/art/build_package_lods.py` and validate them with `tools/art/validate_package_lods.py`.

The manifest is `assets/source/textures/packages/candidates/lod/LOD_MANIFEST.json`. These files are not connected to runtime product definitions or Godot; visual selection, readability at zoom 0.5/1/2, and runtime wiring remain open work.
