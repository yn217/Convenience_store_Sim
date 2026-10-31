# Issue #13 character UI mockup

This directory contains one visual proposal for the Issue #13 expiration,
FEFO, and waste-loss management screen.

## Scope

- `issue13_expiry_rikka.png` is a static design reference for lot expiration,
  earliest-expiry sales priority, and waste history.
- Koharu Rikka is placed beside the lot status panels as a short-form guide;
  the lot cards and disposal ledger remain the primary interaction surface.
- The intended information architecture is: lot list, FEFO sales order,
  quantity, expiration date/time, sellable and expired quantities, waste cost
  based on purchase cost, and one-time disposal notice.
- This asset does not implement lot reservation, expiry transitions, ledger
  posting, save/load, or deterministic simulation behavior.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

