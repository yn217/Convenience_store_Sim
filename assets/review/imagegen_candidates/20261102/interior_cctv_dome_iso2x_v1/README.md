# Dome CCTV — ImageGen review candidate

- One Codex subagent generated one candidate with the built-in image generator. `source_original.png` is an unchanged byte copy; no crop, resize, recolor, or edge cleanup was applied. The checkerboard JPEG is inspection-only.
- Content: camera lens and hemispherical housing are identifiable. The mount is larger and more sculpted than the compact low-profile request, but it remains a single coherent assembly with no text or extra scene objects.
- Style: **FAIL for game-ready art**. The source is photorealistic with glossy material and strong specular lens reflections rather than the restrained isometric miniature-game style.
- Alpha: true RGBA. At alpha >=8, bounds have 12%+ margin on all sides. At alpha >=1, faint colored fringe/haze reaches the left edge and has under 12% margin on every edge. Keep the original unchanged and treat the edge as a failure for game use.
- Projection: broad dome has no reliable long axis; visible bracket/camera axis looks perspective-rendered, not validated iso2x. No control points, world dimensions, installation orientation, footprint, anchor, or Godot capture were checked.
- Verdict: `review_only`, not runtime ready. Fix material style and alpha-edge fringe in a future regenerated source; do not crop or stretch this one to hide defects. `runtime_approved:false`.
