# Transparent package cutout pilot

This stacked PR contains a transparent-background package cutout pilot. The
fictional onigiri, tea, and cup-noodle candidates were edited from the
lossless left/right crops in PR #67. The original boards and crops remain
unchanged.

Verification performed locally:

- All six outputs load as `RGBA` PNGs.
- Alpha extrema include both transparent and opaque pixels (`0..255`).
- The front-facing package remains fully visible from cap to contact edge.
- The output is intentionally not treated as an iso2x sprite: dimensions,
  four directions, slot anchor, and inventory LOD are still pending.

The edit prompt required preservation of the fictional artwork and removal of
only the studio background. Human review is still required for edge cleanup,
trademark/text inspection, licensing, and selection of the final concept.
See `assets/source/textures/packages/CUTOUT_PROVENANCE.json` for the source
mapping and unavailable model/seed fields.
