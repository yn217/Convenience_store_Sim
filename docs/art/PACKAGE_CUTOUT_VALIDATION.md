# Package cutout validation

The six normalized transparent staging candidates (`*_cutout_v02.png`) are
checked by `tools/art/validate_package_cutouts.py`. The preceding v01 files
are retained as the untrimmed edit outputs.

The validator records:

- RGBA mode and non-empty alpha;
- visible alpha bounding box;
- bottom contact-edge presence;
- horizontal edge padding;
- a 0.5x / 1x / 2x visual preview.

Normalization is reproduced with `tools/art/normalize_package_cutouts.py`: it
keeps 8 px of top/side padding, removes excess transparent margin, and aligns
the visible bottom to the candidate canvas contact edge.

This is a source-art gate only. It does not prove the common `iso2x_v1`
projection, four directions, slot anchors, stock LOD behavior, or Godot
occlusion. Those remain separate acceptance conditions.
