# Issue #139 character UI mockup

This directory contains one visual proposal for the Issue #139 screen where
the store manager explains capsule-toy equipment, limited series, remaining
prizes, replenishment, and sales.

## Scope

- `issue139_capsule_rikka.png` is a static design reference for the capsule
  toy management screen.
- Koharu Rikka is placed beside the management panels as a short-form guide;
  the machine and stock cards remain the primary interaction surface.
- The intended information architecture is: 1/3/5-machine equipment cards,
  fictional series, finite prize counts, limited-series state, refill action,
  empty-machine warning, and revenue summary.
- This asset does not implement machine interaction, prize selection,
  inventory, ledger rules, seed behavior, save/load, or customer flow.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

