# Idol 3D raw assets — 2026-10-31

User direction: generate and register 3D first; adjustment is delegated to another chat.

Included: POS register, empty general shelf, green-tea bottle, C02 coffee machine. Each model.ply is a standard 3D Gaussian Splat with 262,144 Gaussians. This is not a triangle mesh/GLB. input_camera.json is the predicted source camera, not a game placement transform.

No 2D sprites, projection corrections, runtime integration, trained weights, or virtual environments are included in this delivery. The unchanged input-image SHA and generation settings are in each manifest.

Data checks: PLY parsing, attribute finiteness, Gaussian count and SHA-256. Shape quality is unapproved: earlier custom 2D renders showed distortions, and model-versus-renderer cause was not isolated. Keep raw data for adjustment/review; do not silently treat it as runtime-approved geometry.

Related issues: #125 (3D asset roadmap), #9/#22 (base fixtures), #29 (provenance). Idol is Apache-2.0; DINOv3 and FLUX.2-dev have separate usage terms. No commercial/release approval is claimed.

## P0 continuation batch

Added F01 upright frozen-food case, S02 multicopier, C01 fried hot-snack cabinet, C03 steamed-bun warmer. All are raw single-image Idol candidates; design/shape/runtime approval remains false. The original reference paths and hashes are in each manifest. Source images remain at their existing review paths or the local Idol inputs directory; this commit adds no 2D sprites. Existing ATM issue #156 remains with the adjustment lane and was not overwritten.
