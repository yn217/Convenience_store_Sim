# Package source-art staging gate

Run the focused gate with:

```powershell
python tools/art/validate_package_staging.py
```

The gate checks provenance paths, review-only mappings to existing product
visual IDs, six normalized transparent cutouts, and six 256×256 RGBA source
canvases. It intentionally does not check four-direction iso2x rendering,
Godot integration, inventory LOD, or depth composition; those remain later
acceptance gates.
