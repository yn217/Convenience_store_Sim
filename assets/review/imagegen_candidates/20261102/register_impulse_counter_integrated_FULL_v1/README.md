# Register impulse counter — review candidate

Codex ImageGen produced a single checkout fixture with its candy/gum display integrated. The untouched 1536×1024 RGBA source, prompt, checkerboard preview, SHA and focused QA are included.

**QA: FAIL for game use.** Content integration reads well, but the rendering is glossier/more realistic than the game reference, projection is not calibrated to `iso2x_v1`, and a gray background haze remains visible on checkerboard. The alpha bounding box touches the lower image edge. Do not crop/scale/warp this to disguise those defects. Exact footprint, ground anchor, and Godot display are unverified. `runtime_approved:false`.
