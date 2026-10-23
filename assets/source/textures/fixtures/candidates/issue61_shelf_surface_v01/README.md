# Issue #61 / #22 — Shelf surface material candidates

Two generated albedo candidates for clean Japanese convenience-store fixtures:

- `powdercoat_white_a.png` — satin white powder-coated steel appearance.
- `resin_lightgray_b.png` — slightly gray durable ABS/resin appearance with fine stipple.
- `PREVIEW.png` — 3×3 repeat and opposing-edge inspection for both candidates.
- `provenance.md` — exact prompts, generation/processing record, QA observations, and limitations.

## Status

These are **unapproved visual albedo candidates**, not complete PBR materials or finished fixture assets. `runtime_approved: false`. Commercial-use review is pending. No fixture geometry or game/runtime code is included.

The repeat preview shows faint boundary variation (more apparent on A's vertical tile joins). Neither image is claimed to be seamless. Recheck after UV placement and normal game filtering/mipmapping; avoid large uninterrupted tiled surfaces until reviewed.

## Reproduction / inspection

1. Generate each material separately with the exact built-in ImageGen prompt in `provenance.md`.
2. Convert to RGB and resize to 1024×1024 with Pillow `Image.Resampling.LANCZOS` if the generator returns a different square resolution. Keep the original generated files outside the repository if needed for provenance; the repository candidates are the normalized outputs.
3. Build a 3×3 repeat at 256 px per tile and compare the four opposing 64 px edge strips. `PREVIEW.png` records the inspection for this revision.
4. Review the texture on the actual fixture UVs in Godot before considering runtime use.

Pillow is only used for deterministic resizing and preview composition; this is not a full material or Godot validation pipeline.
