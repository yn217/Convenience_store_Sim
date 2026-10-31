# Issue #131 character UI mockup

This directory contains one visual proposal for the Issue #131 screen where
the store manager explains soft-serve and frappe equipment, ingredients, and
preparation status.

## Scope

- `issue131_softserve_rikka.png` is a static design reference for the
  soft-serve / frappe management screen.
- Koharu Rikka is placed beside the equipment and stock information as a
  short-form guide; the panels remain the primary interaction surface.
- The intended information architecture is: equipment list, ingredient stock,
  preparation timers, cleaning/status, shortage warnings, placement, and
  sales forecast.
- This asset does not implement equipment, recipe, inventory, timing,
  accounting, customer flow, save/load, or deterministic simulation behavior.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

