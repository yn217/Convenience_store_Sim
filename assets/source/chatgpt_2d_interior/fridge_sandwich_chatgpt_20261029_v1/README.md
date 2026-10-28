# Sandwich / packaged bakery chilled display — ImageGen original, not hot-snack warmer

ChatGPT was asked for a tabletop hot-snack warmer but produced a **large chilled sandwich/packaged-bread case**. It is intentionally filed by the **visible content**, not by the failed prompt.

## Images registered in this draft PR

- `source_original.png` — untouched **1536×1024** original PNG, SHA-256 `de206b8efcb37f6fd60486f577667a39a9e25bf7dbd4a7568137347a64b382c1`
- `source_fullres.webp` — full-resolution high-quality alternate, SHA-256 `b905184a28bcb26a1f7f19c22561d4907249096f672f655ba9ddc6e3a6edf1b3`
- `game_512.png` — 512px-wide renderer LOD image, original aspect ratio
- `game_256.png` — 256px-wide renderer LOD image, original aspect ratio
- `manifest.json` — truthful classification, hashes, projection target, approval state

**Actual image binaries are committed** in this branch, not merely listed as filenames. Their Git blob SHA IDs are recorded in `manifest.json`.

## Remaining Codex tasks / STOP conditions

- [ ] Verify `iso2x_v1` with projected 2:1 ground axes, world r0 access +X, matching 1×2 or measured footprint. Do not assume footprint from image aspect ratio.
- [ ] Verify front-of-case directions and ground pivot against Godot screenshots at actual zoom.
- [ ] Eliminate dark studio matte and halo while protecting glass, products, and reflections; inspect alpha at all edges.
- [ ] Japanese retail product/package density review, renderer integration and performance check.
- [ ] Do NOT reclassify this as a hot-snack case or promote it to canonical fixture before user approval.
- [ ] Keep `runtime_approved:false`, Draft PR, no main merge.

Related: #163, #157, PR #164.
