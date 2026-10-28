# Issue #91 cup-noodle shelf candidate

Blender candidate generated from the shelf_noodle blueprint (0.92 × 1.92 × 1.70m, footprint 1 × 2m) and iso2x_v1. It contains FULL/HALF/EMPTY × 4 true 3D rotations, with two offset product depths per selected display slot.

- Cup noodle dimensions: 0.110 × 0.110 × 0.120m, matching the shared product blueprint.
- FULL/HALF/EMPTY contain 64/32/0 modeled cups. HALF is a sparse arrangement, not a transparency change.
- Two generated fictional flat wrap arts (spicy miso and seafood soy) are UV-mapped around the tapered cups.
- contact_sheet.png, before_after_full_r0.png, manifest.json, provenance.json, calibration.png, and validation_report.json provide visual and machine-readable review evidence.

Run using the three commands in the companion renderer instructions: Blender 2.91 render_inventory_fixture_states.py --fixture shelf_noodle, then build_inventory_fixture_states.py, then validate_inventory_fixture_states.py.

runtime_approved:false. The PNGs have not been loaded into Godot or checked in the game camera, runtime sorting/selection, zooms, adjacent fixture scene, or commercial-license review. Back-facing rotations show the shelf back; some package edges may peek around the rear because the rack is open-sided.
