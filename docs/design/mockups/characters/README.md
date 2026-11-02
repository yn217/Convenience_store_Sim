# Issue #18 character UI mockup

This directory contains one visual proposal for the Issue #18 advertising
budget and cost-effectiveness screen.

## Scope

- `issue18_advertising_rikka.png` is a static design reference for comparing
  next-day advertising tiers and their predicted effects.
- Koharu Rikka is placed beside the budget comparison as a short-form guide;
  the budget cards, chart, and billing history remain the primary interaction
  surface.
- The intended information architecture is: five budget tiers, diminishing
  visitor multiplier, predicted visitors, lost customers, gross profit,
  operating profit, one daily charge, insufficient-funds warning, and next-day
  application state.
- This asset does not implement billing, date boundaries, cash validation,
  demand calculation, save/load, or event/advertising coefficient rules.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

