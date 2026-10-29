# shelf_general FULL integrated candidate v4

- Producer: image-generation subagent `Hubble`, requested with GPT-6 Luna; generated 2026-10-30.
- Source: `shelf_general_full_integrated_candidate_v4.png`, 1254×1254 RGBA, 1,181,431 bytes. Preserved unchanged after generation; no cropping, resizing, repainting, or alpha cleanup.
- SHA-256: `09644a3708c9201364e6b62d8118f1af5855a03b313b4ced133964ab8373da89`.
- References: the empty shelf projection guide is the geometry authority; the game screenshot is style-only.
- Prompt brief sent: preserve the projection guide's four open shelves, thin lips, uprights, back panel and dark plinth; add fictional Japanese snack/bread package fronts on those exact shelf faces as one integrated image; no roof, deep display case, floating cards, thick sidewalls, glow, floor, text or logos; require 15% clear margins. The image service's exact internal prompt was not retained.

## Focused review

- Four shelf rows and dark base are visible. Shelf and goods are composed as one sprite image; product faces are more readable than v3.
- The whole-image alpha mask IoU against empty v13 is 0.717 at alpha>127 without transformation. This includes product coverage and is **not** a structural match score. The side-by-side canvases make the remaining shelf/depth differences visible.
- Edge diagnostic from Hough line segments: projection guide median slopes are −0.507/+0.503; candidate medians −0.528/+0.556. This indicates one projected axis is close and the other drifts. It is not a point-to-point calibration; projection remains unverified.
- Alpha>127 bbox `[216,156,938,1141]` leaves margins L17.22%, R25.20%, T12.44%, B9.01%. Bottom fails 12% safe margin; a small fringe remains.
- Several packages/cups still have visible top/side depth. They are not separate sprites, but the no-thick-volume rule is only partially met.
- Intended contract: `shelf_general`, 1×2 tiles, 0.92×1.92×1.50m, access edge E. Exact dimensions, anchor, Godot zoom and EMPTY/HALF consistency are unverified.
- QA comparison and background previews are derivative-only; source was not altered. `runtime_approved:false`.
