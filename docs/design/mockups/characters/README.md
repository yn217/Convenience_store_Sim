# Issue #130 character UI mockup

This directory contains one visual proposal for the Issue #130 screen where
the store manager explains bakery and pizza production states.

## Scope

- `issue130_bakery_rikka.png` is a static design reference for the bakery /
  pizza production management screen.
- Koharu Rikka is placed beside the production dashboard as a short-form guide;
  the batch and inventory cards remain the primary interaction surface.
- The intended information architecture is: production line, ingredients,
  baking batches, remaining time, ready-to-sell quantity, expiration timer,
  and shortage warning.
- This asset does not implement equipment, recipes, lot tracking, timing,
  accounting, save/load, customer flow, or disposal behavior.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

