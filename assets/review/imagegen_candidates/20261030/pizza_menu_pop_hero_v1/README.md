# Pizza menu POP — review candidate v1

- Generated with built-in Codex image_gen on 2026-10-30.
- Untouched source: `source_original.png`, 1334×1179 PNG, 946247 bytes, SHA-256 `83df3fcda318c6b943c20ec3a34292d4f30bbce013097850563aeef6ca6f67e3`.
- Intended for Issue #130's fictional in-store pizza menu POP.
- Exact prompt:

```text
Create one standalone 2D game sprite for a Japanese convenience-store in-store bakery/pizza menu POP requested by Issue #130: a small freestanding tabletop A-frame promotional menu sign, single object, front and right side visible in a restrained iso2x-like view. Polished illustrated Japanese convenience-store management game art, clean readable silhouette, crisp edges, warm red/orange/cream palette. Sign has one central white printed panel with a simple appetizing pizza illustration and exactly these Japanese words, large and clearly legible: 「焼きたてピザ」. Add a small fictional price line exactly 「¥398〜」 beneath it. Do not add any other lettering or numbers. Compact dark stand/feet, full sign entirely in frame. Transparent PNG, opaque sign/stand pixels, clean cutout; transparent margin at least 12% all around; no shadows/glow touching the edge. No room, counter, floor, people, other objects, logos, brands, watermark, detached floating graphics, or 3D render look. Game-ready flat illustrated asset, not a photo.
```

## Focused QA — FAIL / review only

- A-frame sign is readable; headline `焼きたてピザ` and price `¥398〜` are present, with a pizza illustration.
- Alpha counts: 1,042,795 alpha 0; 8,476 alpha 1–127; 519,999 alpha 128–254; 1,516 alpha 255. Most sign/stand pixels are semitransparent.
- Alpha-positive bbox `[49,46,1317,1139]`; margins L/R/T/B 3.67/1.27/3.90/3.39%. The faint alpha fringe is particularly close to the right canvas edge.
- A-frame side angle is not calibrated to iso2x_v1 control points. World dimensions, anchor and Godot display remain unverified.
- No crop, resize or alpha repair was applied; white-matte preview is QA-only.
- Decision: **FAIL** for runtime acceptance; `runtime_approved:false`.
