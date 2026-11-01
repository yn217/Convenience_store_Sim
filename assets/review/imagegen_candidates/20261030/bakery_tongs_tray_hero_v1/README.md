# Bakery tongs and tray — review candidate v1

- Generated with built-in Codex image_gen on 2026-10-30.
- Untouched original: `source_original.png`, 1774×887 PNG, 736805 bytes, SHA-256 `eced978664b46fd96a207fef551111f939f5d9b0b6b17cc89161ef7e7b1c11a4`.
- Exact prompt:

```text
Create one standalone 2D game asset candidate for Issue #130: a grouped bakery serving utensil set consisting of one shallow rectangular stainless tray with one pair of metal serving tongs resting naturally on the tray. Treat them as one grouped prop/sprite, not floating separate cards. Japanese convenience-store bakery back-counter context implied only through practical utensil design; no furniture. Clean stylized illustrated game art, crisp silhouette, moderate detail, readable at small in-game size. Iso2x-like 2:1 view, showing the tray top and front edge, tongs clearly recognizable. Genuine transparent PNG background. Object surfaces should be fully opaque (alpha 255); clean cutout with no background, vignette, glow, or large shadow. Leave at least 12% empty transparent margin on every side. No food, baked goods, other tools, hands, people, room, floor, text, logo, brand, watermark, thick box packaging, or detached floating elements.
```

## Focused QA — FAIL / review only

- One tray with a pair of serving tongs resting on it; both read as a grouped bakery-prep prop.
- Alpha counts: 1,184,114 alpha 0; 7,306 alpha 1–127; 381,404 alpha 128–254; only 714 alpha 255. Most prop pixels are semitransparent, which will wash out against darker game backgrounds.
- Nonzero-alpha bbox `[94,39,1703,850]`; margins L/R/T/B 5.30/3.95/4.40/4.06%, below the requested 12% safe margin.
- Perspective-like tray axes are not aligned to measured iso2x_v1 control points. No game scale, ground anchor, or Godot display was verified.
- No crop, resizing, repaint, or alpha repair was applied. `qa_preview_white.png` is a review-only matte composite.
- Decision: **FAIL**; keep `runtime_approved:false`.
