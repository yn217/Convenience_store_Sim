# Gondola FULL integrated candidate v5

- Producer: GPT-6 Luna subagent Lovelace using built-in ImageGen; generated 2026-10-30.
- Source PNG: `gondola_full_v5.png`, 1536×1024 RGBA, 1,736,822 bytes. Copied unchanged; SHA-256 `5c0542b415772feab9dd5326d1829dab9739db1e05d6418dd3815a0b82f8fc3d`.
- Prompt recorded below. A transparent background and >=14% clear margins were requested; output has alpha but retains a dark low-alpha fringe and does not meet top/bottom safe margins.
- References: EMPTY projection guide is geometry authority; game screenshot is style-only.
- This is a review candidate only, `runtime_approved:false`.

## Focused QA

- Integrated shelf plus goods and four stocked tiers are present. Product fronts are colorful and readable at source size.
- Alpha>127 bbox: `[444, 111, 1159, 951]`; margins L/R/T/B: 28.91% / 24.54% / 10.84% / 7.13%. Required 12% minimum is not met on top/bottom.
- Pouches, cups and bakery packages still show substantial top/side volume, so the no-thick-volume goal fails.
- Shelf shape and camera remain visually different from EMPTY guide. `comparison_preview.png` scales both images to fit panels and is for visual inspection only, not pixel-calibrated proof. No point controls, world anchor or Godot runtime validation were done.
- Overall: FAIL. No cropping, resizing, repainting or alpha cleanup was applied to the source.

## Exact prompt brief sent to generator

Use case: stylized-concept. Asset type: review-only game sprite for a Japanese convenience-store interior. Primary request: one integrated FULL four-tier single-sided open gondola with stocked products. Input images: Image 1 is the empty shelf geometry/projection authority; Image 2 is game style only. Scene/backdrop: transparent. Composition: centered isolated fixture with at least 14% clear alpha margin on every edge. Keep a shallow retail shelf depth around 30–35 cm, thin top shelf, four matching shelf rows, narrow uprights and dark plinth; products sit on the front selling edge and form continuous readable package fronts. Use fictional Japanese snack and bread pouches, simple cups, flat game-art packaging with nearly no visible top/side extrusion. Preserve the empty guide silhouette and camera orientation. Avoid roof/canopy/header, deep boards, dramatic perspective, photoreal gloss, floor shadow, halo, detached floating product cards, thick cuboid products, logos and legible brand text.
