# Painted flower planter candidate

`flower_planter_painted_v1` adds a pale concrete rectangular planter with dense green leaves and small yellow, white and pink flowers, following the target's storefront planting.

Three image-only attempts were rejected for projection mismatch. The fourth uses an original geometric guide with exact ±0.5 edges. Opaque source-edge fitting measures +0.507659 and −0.524057, so the residual maximum slope error is 0.024057. This is a measured candidate, pending real-game approval; the guide does not justify claiming exact geometry in the generated output.

The existing `PropSprites` consumer can read rotations 0 and 2. They intentionally share the same symmetric planter art. Rotations 1 and 3 are absent because artwork for the perpendicular direction has not been generated. Do not mirror or stretch the sprite to invent these views.

Use world ground-centre placement and the common zoom/2 source scale. Canvas 512×512, anchor (226,293), nominal world dimensions 1.6×0.65×0.65m. The packaging script uniformly rescales the image and preserves RGBA alpha. It also checks measured edge slopes, transparent alpha range and opaque ground anchor.

Place on pavement clear of doors; do not add input interception, pathfinding, economics or save fields. No cast shadow is baked into this asset. Any ground contact shadow must follow the projected footprint separately.

`QA.json` and `PROVENANCE.json` accompany the PNG. The source and structural guide remain under `assets/source/exterior/flower_planter_painted_v1`. The package is not referenced by a runtime renderer in this commit.
