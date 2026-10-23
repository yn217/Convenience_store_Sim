# 256x256 package source canvases

`tools/art/build_256_source_canvases.py` fits the six normalized package
cutouts into 256x256 RGBA staging canvases. Each object is centered and its
visible bottom is placed at the canvas bottom, matching the source-canvas
convention used by the existing product pipeline.

This is not an iso2x render and does not establish a runtime visual ID. The
manifest records the source path, output path, object size, and provisional
bottom anchor. Four directions, shape-specific dimensions, slot projection,
and runtime fallback remain separate gates.
