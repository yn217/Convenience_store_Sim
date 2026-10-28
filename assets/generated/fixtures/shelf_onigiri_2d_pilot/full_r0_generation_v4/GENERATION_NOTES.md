# shelf_onigiri FULL/r0 generation v4

New full fixture-and-stock sprite, saved separately; prior candidates are preserved. The generated image shows three open shallow shelf tiers and one visible row of onigiri per tier. Product scope was checked against `data/products/mvp_v1.json`: current `rice_ball` SKUs are rice_001 (salmon), rice_002 (plum), and rice_003 (tuna-mayo); no sushi SKU is present.

`raw_generated.png` is the unmodified generation. `sprite_fit_experimental.png` is a uniform-scale, anchor-relative 442x434 fit candidate. It is a QA draft only; it is not runtime-approved. `qa_metrics.json` has alpha bounds and measured long-edge slopes.

Known issue: the raw long-edge slope is outside the canonical r0 tolerance (target -0.5, measured value in the JSON). Therefore this image is not approved for runtime or expansion to other states/rotations.
