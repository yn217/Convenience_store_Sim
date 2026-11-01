# fridge_daily_open_case_FULL_v1 — review candidate

Generated with Codex built-in ImageGen using the registered sandwich-case illustration as food/style reference only. `source_original.png` is copied byte-for-byte from ImageGen; no redraw or resampling.

## Focused QA
- Subject: open refrigerated display with sandwiches, salads, chilled meals and dessert cups; goods are visually integrated on three tiers.
- Geometry: **FAIL**. Output is a wide multi-bay horizontal wall case, visually incompatible with the required compact 1×2 fixture module. The long axis is visibly too shallow (rough visual slope ~0.18–0.20 vs target +0.5), though it slopes in the intended down-right direction. Do not anisotropically scale it to conceal the mismatch.
- Transparency: see `qa_report.json`; raw margins are measured against alpha thresholds. The dark-looking background in preview is transparent where alpha is zero; the source is RGBA.
- Text/branding: no prominent legible real brand text observed, but the package/price details remain illustrative and are not SKU data.
- Dimensions, footprint fit, ground anchor, access side, full game-scale readability, and Godot behavior are not validated. `runtime_approved:false`.
