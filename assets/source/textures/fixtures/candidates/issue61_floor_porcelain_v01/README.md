# Issue #61 — Floor porcelain albedo candidates

Two square top-down floor-surface candidates for Issues #61 and #22. These are material-source images, not isometric floor sprites and not a change to the game's 2:1 projection.

- `porcelain_warm_a.png`: warm glossy ivory, subtle 2×2 grout; the 3×3 preview shows repeated highlight bands, so this is a **non-tileable candidate** pending revision.
- `porcelain_warm_b.png`: warm greige stone-mottled, matte-leaning; no dominant hard join in the preview, but repeated motifs remain and seamlessness is not certified.
- `PREVIEW.png`: both 1024px sources repeated 3×3 at 384px/repeat, side by side.
- `provenance.md`: prompts, generation details, edge diagnostics and approval limits.

Intended concept: a 1 m × 1 m surface with four equal subtiles. Physical UV scale is unconfirmed. Existing 1 m world tile, 128×64px screen projection and 256×128 source-pixel calibration are unchanged. UV and Godot use are unverified. Both remain `runtime_approved: false`; commercial-use review is pending.

Reproduction: use the exact prompts in `provenance.md` with Codex built-in ImageGen (A includes an edit pass). ImageGen is stochastic. It returned 1254×1254 RGB; final assets were normalized to 1024×1024 RGB with Pillow LANCZOS. Build the preview by resizing each to 384×384 and repeating 3×3 on a 2304×1208 RGB canvas with a 56px title strip. Statistics are diagnostics, not a seamlessness certificate.
