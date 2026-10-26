# Painted sakura seasonal variant

`cherry_tree_painted_v1` is an imagegen edit of the project's painted green tree. The visible trunk, root position, dimetric view, crown mass and upper-left daylight are retained; the foliage becomes fine pale pink and cream cherry blossoms with dusty pink shaded clusters.

Use the exact same contract as `green_street_tree_v1`: 720×720 source canvas, root anchor (360,639), nominal crown 2.8×2.8m and height 3.5m, source scale 2. No per-instance scaling or screen-space positioning. All rotations reuse this approximately radial tree art.

The source canopy's opaque silhouette overlap (IoU) is 0.9510, reflecting small petal-edge differences. The original source root pixel (649,1200) remains opaque (alpha 253). The shared packaging transform retains the same root placement, with no separate rescaling or recentering for the spring variant.

RGBA transparency, outer margin and root anchor checks pass. Very small coloured semi-transparent edge remnants are recorded in `QA.json`; review actual pavement composites at high zoom before final acceptance. This is a candidate until real-game QA. No renderer, season state, save format or collision logic is changed.

Rebuild with `python tools/assets/package_exterior_tree.py --asset cherry_tree_painted_v1`. Generation prompt, source and validation data accompany the package.
