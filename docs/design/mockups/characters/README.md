# Issue #10 character UI mockup

This directory contains one visual proposal for the Issue #10 product catalog
and price-setting screen.

## Scope

- `issue10_product_pricing_rikka.png` is a static design reference for product
  categories, SKU prices, margin, and demand preview.
- Koharu Rikka is placed beside the pricing cards as a short-form guide; the
  catalog and price editor remain the primary interaction surface.
- The intended information architecture is: category tabs, SKU cards, cost,
  current and new selling price, expiration, demand coefficient, expected
  sales, margin preview, integer-yen validation, invalid-price warning, and
  price-history note.
- This asset does not implement the product master, price validation,
  transaction snapshots, category compatibility, or save/load behavior.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

