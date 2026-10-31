# shelf_drink_open_gondola FULL v1 — review-only candidate

Unmodified ImageGen source `source_original.png`: 1254×1254 RGBA; SHA-256 `175fa27d035f8312b19123fc9aa4e8a36096416ee6c42be8bc3781cdf3c4ba84`. Shelf and beverage stock are integrated in one sprite, with four visible stocked tiers.

**Rejected for acceptance:** alpha>8 margins L/T/R/B = 13.32% / 8.69% / 13.48% / 4.55%; top and bottom fail the 12% gate. Faint alpha≤1 reaches left/bottom borders. Broad white shelf surfaces and the base's top face remain visible. Axis assignment, 0.47917 fixture ratio, access edge, world anchor, and Godot scale are unverified.

See `qa.json`, `prompt_record.txt`, and `comparison.png`. No crop/stretch or runtime/Renderer change. `runtime_approved:false`.
