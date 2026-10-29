# shelf_general EMPTY candidate v9 — superseded ratio experiment

- Generator: GPT-6 Luna subagent using Codex built-in ImageGen.
- Original image copied unchanged from the subagent's generated PNG; no crop, resize, repaint, or alpha cleanup.
- Canvas: 1254×1254 RGBA; SHA-256 is recorded in `QA.json` and `asset_candidate.json`.
- The supplied guide had a mathematically correct ±0.5 screen slope, but the wrong dimension ratio 0.3889. The actual game projection in `scripts/presentation/iso_projection.gd` maps each world axis to equal screen length per metre. The canonical `shelf_general` entry in `data/fixtures/mvp_v1.json` has 0.92×1.92×1.50 m, so depth/long must be 0.92/1.92 = 0.47917.
- Independent GPT-6 Luna review: only three usable product shelves excluding the base; roofless single-sided structure is recognizable; the top extension/base are irregular; finish is too glossy. Pixel alpha touches left/top/bottom edges.
- Result: **FAIL; superseded input ratio**, review-only, `runtime_approved:false`. Do not use for runtime or further state generation.
- Comparison: `comparison_guide_v9.png`.

## Exact ImageGen prompt used by the subagent

```text
Create exactly one finished 2D game sprite of the EMPTY single-sided Japanese convenience-store gondola shown in reference image 1. Reference 1 is the authoritative geometry and projection guide; trace its silhouette and component positions faithfully without changing viewpoint, proportions, spacing, shelf shapes, or angles. It is 1500x1500 with transparent margins. Include exactly FOUR distinct, independent merchandise shelf boards. The low separate kick plate/base below them is not a shelf and must not be counted as one. Keep both slim uprights, the back panel, all four shelf boards, and the separate narrow kick plate in the exact positions and sizes shown. No roof, canopy, top cap, products, signs, labels, or extra objects. Projection is fixed: long shelf edges screen-right-down vector (540,270); depth edges screen-right-up vector (210,-105); depth/long ratio 0.389. Preserve the guide's shelf shape and size; do not reinterpret the back panel or shelf count. Use reference 2 only for a soft, polished miniature management-game painted style: warm restrained light, subtle painted shading, gentle edges, matte pale warm-gray painted steel, understated charcoal kick plate. Reduce strong metallic shine and thick black outlines. True transparent RGBA background, keep at least 12% clear margin on every side, with no nontransparent pixels touching any canvas edge. This is geometry-faithful asset rendering, not a new design.
```

The recorded prompt confirms the wrong ratio was explicitly supplied; v9 is superseded and must not be treated as a shape candidate.
