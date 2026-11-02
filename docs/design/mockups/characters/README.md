# Issue #24 character UI mockup

This directory contains one visual proposal for the Issue #24 store-analysis
overlay and obstruction-helper screen.

## Scope

- `issue24_overlay_rikka.png` is a static design reference for normal,
  placement, and analysis modes over the store view.
- Koharu Rikka is placed beside the analysis controls as a short-form guide;
  the store, selected fixture, warning legend, and inspector remain the
  primary interaction surface.
- The intended information architecture is: selected fixture, stock warning,
  checkout queue warning, blocked access path, grid/access overlay, icon-plus-
  text legend, read-only analysis controls, and sales/stock context.
- This asset does not implement hit testing, mode changes, read-only
  guarantees, occlusion, inventory, queue logic, or performance behavior.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

