# Berry milk pudding — dessert cup label candidates

Two independently generated, flat portrait label-art candidates for the fictional `dessert_cup` SKU. A uses an airy ivory/blush composition; B uses a deep-plum field with a cream medallion. Each depicts berry milk pudding as food artwork and is intended to wrap the side of the Blender cup via UV mapping.

## Package contract

- SKU: `dessert_cup` / berry milk pudding.
- Physical dimensions: diameter `0.100 m` × depth `0.100 m` × height `0.115 m`.
- Source canvas: 1024×1536 px portrait PNG (verify dimensions after any future re-export).
- Intended surface: flat rectangular side label, UV-mapped to the tapered cup side; not a 3D packshot, complete cup texture, or runtime sprite.
- Not included: cup rim/base geometry, lid, nutrition/legal copy, barcode, or readable product text.
- `runtime_approved: false` — no UV seam/taper fit, in-game lighting, zoom, or Godot display validation has been done.
- Commercial-use/licensing review: pending; these candidates are not cleared for commercial release.

## Files

- `label_art_a.png` — ivory, blush and berry palette; generous light negative space.
- `label_art_b.png` — deep plum and cream palette; bold medallion framing.
- `prompts_and_provenance.md` — full generation prompts, process, scope, and review notes.

## Reproduction / integration

The two files are the original built-in ImageGen PNG outputs. To reproduce, use the recorded prompts in `prompts_and_provenance.md` as two separate built-in ImageGen generations, requesting 1024×1536 portrait flat label art. Before integration, import the PNG as a color texture, map it around the cup's tapered side UV island with seam and print-safe margins checked, then inspect a Blender render against the 0.100×0.100×0.115 m package contract. Preserve the source PNGs and do not mark runtime approved without appearance review in the game.

## Provenance and status

- Generator: built-in ImageGen, two distinct prompt calls.
- Generated: 2026-10-24.
- Status: candidate artwork; `runtime_approved: false`.
- Commercial-use/licensing review: pending.
- SHA-256:
  - `label_art_a.png`: `796C0A0DC5F58117851DD5BC63AD66E2B7CF19AF10CFCA6C9548F76DA024189A`
  - `label_art_b.png`: `83313C53E9CD088FA5FB97609E06462A6B8A6EE87FA5598C548E5C20B8CAF131`
