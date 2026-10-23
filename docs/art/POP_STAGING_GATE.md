# POP source-art staging gate

Run:

```powershell
python tools/art/validate_pop_staging.py
```

The gate checks both fictional POP cutouts, their 256×256 RGBA source
canvases, alpha contact/padding, and provenance paths. It does not approve
placement in a fixture, iso2x rendering, depth order, or runtime use.
