# POP source canvases

The two normalized POP cutouts are fitted into 256×256 RGBA staging canvases
by `tools/art/build_pop_source_canvases.py`. This keeps the POP source
separate from SKU product overlays and records a provisional bottom anchor.

The output is not a Godot fixture texture or an iso2x four-direction render.
Human visual/license review and later placement/depth validation remain
required.
