# Baseline fixture material candidates

`MATERIAL_PROVENANCE.json` records two visual material directions for each
baseline fixture: `register_basic`, `shelf_general`, and `fridge_drink`.

Run the focused check with:

```powershell
python tools/art/validate_material_candidates.py
```

These are material studies and source references. They are not fixture sprites,
do not change dimensions or footprints, and must be applied through the common
Blender source and layer pipeline before runtime adoption.
