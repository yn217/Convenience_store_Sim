# Suspended aisle sign — ImageGen review candidate

- Subject: one blank, suspended interior aisle-category sign with a blue accent; one image-generation attempt by a Codex subagent.
- `source_original.png` is copied byte-for-byte from the built-in ImageGen output. It is not cropped, recolored, or resized. The checkerboard JPEG is a separate transparency-inspection derivative.
- Visual check: a single blank cream panel and blue stripe are visible with two thin upright suspension rods. No text or extra props appear. However, the highly glossy metallic appearance and the thin, bright construction read partly like a ceiling light fixture rather than a restrained in-game aisle sign. Style/content is therefore partial, not approved.
- Transparency: the file is RGBA. At alpha >=8, the object bounds have margins L/T/R/B 25.72/16.89/22.40/14.55%, above the prompt's 12% target. Very low alpha (>=1) haze reaches the top, left, and bottom image edges; do not treat the alpha=0 corners alone as proof of a clean cutout.
- Projection: visual estimate only; the long sign axis is approximately ±0.5 screen slope and the hangers look vertical. No control points, world dimensions, ground/celiling anchor, footprint, or Godot projection calibration were supplied or measured.
- Verdict: `review_only`; alpha fringe FAIL at threshold 1, game style PARTIAL, subject readability PARTIAL, iso2x visual estimate only. No runtime hookup or Godot verification.
- `runtime_approved: false`. Keep this asset as QA evidence; do not use it as a production sign without a clean-alpha/style revision and game-camera calibration.
