# Product overlay audit — 2026-10-23

This is a focused evidence record for Issues #12 and #26. It does not claim
that the Godot runtime has adopted the product overlays.

## Scope

- Reusable product shapes, rather than SKU-baked shelf images.
- Four deterministic directions per shape.
- 24 visual IDs mapped to eight shape families.
- Static inventory-state preview for `empty`, `low`, `medium`, and `full`.
- Back-to-front ordering of projected slot overlays.

## Local evidence

The audit was run in the isolated asset worktree at commit
`9084c85` (`fix: order product overlay slots back to front`):

```text
python tools/assets/validate_products.py
product check: 8 shapes, 4 directions each, 24 SKU mappings, 0 problems

python tools/assets/compose_product_lod.py
wrote build/asset_audit/product_lod/shelf_general_row0_lod.png
```

The rendered preview was visually inspected. It contains four distinct stock
states for each of four rotations. This verifies the source-art composition
path and ordering diagnostic only; it is not a Godot gameplay screenshot.

## Current acceptance status

- Shape/direction/catalog references: PASS for the audited asset worktree.
- Empty/low/medium/full source preview: PASS for the audited fixture/slot data.
- Slot order diagnostic: PASS after the back-to-front correction in `9084c85`.
- AI package texture adoption: pending PR #65 review and downstream crop/texture approval.
- Runtime stock synchronization: not proven here; requires Godot integration and gameplay-state testing.
- Glass/front-layer depth composition: not proven here; remains an implementation concern for #26.

## Reproduction

Run from a checkout containing the generated product and fixture assets:

```powershell
python tools/assets/validate_products.py
python tools/assets/compose_product_lod.py
```

Do not close #12 or #26 based on this audit alone. The remaining runtime and
visual acceptance gates require the implementation owner to run the game with
the same stock states, directions, zoom levels, and occlusion cases.
