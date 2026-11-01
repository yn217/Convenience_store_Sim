# shelf_onigiri FULL/r0 v5 generation attempts

All outputs are isolated prototype artifacts; none are runtime-approved. Camera target is derived only from `assets/generated/fixtures/shelf_onigiri/shelf_onigiri_0_body.png` (measured canonical long-edge slope -0.4971; target -0.5, tolerance ±0.05). v4 was used only as a merchandising/form reference in the attempts where noted.

| Attempt | Long-axis median | Angle | Visual/crop gate |
|---|---:|---|---|
| 01 | -0.50616 | PASS | FAIL: broad empty top and excess blank shelf depth planes |
| 02 | -0.42481 | FAIL | Preserves dense three-tier onigiri form; angle follows composition reference too closely |
| 03 | -0.46443 | PASS | FAIL: opaque pixels touch raw bottom edge; base could be clipped |
| 04 | -0.48725 | PASS | Best current draft: three tiers, one front row each, onigiri only; uniform crop/scale leaves the raw line angle unchanged; normalized base has margin |

Attempt 04 files include untouched `raw_generated.png`, `sprite_fit_uniform.png` (uniform scale only), side-by-side comparison and a 50% canonical overlay. Measurements and alpha boxes are in its `qa_metrics.json`. The candidate remains `runtime_approved:false`; the remaining visual gate is human confirmation of shelf depth and full-row density.
