# Issue #91 inventory-state shelf candidates

This directory contains candidate complete-fixture sprites for the three baseline inventory fixtures:

- `shelf_general`: 0.92 × 1.92 × 1.50 m
- `fridge_drink`: 0.92 × 1.92 × 2.00 m
- `shelf_noodle`: 0.92 × 1.92 × 1.70 m

Each fixture has `full`, `half`, and `empty` states for rotations `r0`–`r3`, plus separated body/products/shadow layers. The refrigerator additionally has `glass_front`.

These are deterministic source candidates generated for review. They are not runtime-approved: Blender camera/physical calibration, Godot state switching, inventory-event integration, and in-game before/after screenshots remain open work.

Run the focused packaging check from the repository root:

```powershell
python tools/art/validate_inventory_state_assets.py
```
