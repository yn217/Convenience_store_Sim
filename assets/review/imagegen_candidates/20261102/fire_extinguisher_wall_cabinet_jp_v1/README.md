# Fire extinguisher wall cabinet — review candidate only

- Asset ID: `fire_extinguisher_wall_cabinet_jp_v1`
- Source: Codex ImageGen, 2026-11-02. `source_original.png` is copied byte-for-byte from the generated output; do not edit it.
- Intended target: wall-mounted store safety fixture, front face visible, small game-scale painted isometric style.
- Review status: **FAIL for runtime use pending new source art**. The cabinet is recognizable and alpha is clean on checkerboard, but the visual top plane/depth is much too broad for a shallow wall cabinet. Do not hide this with nonuniform scaling or perspective warping.
- Geometry, exact projection, world scale, wall anchor, occlusion and Godot display are not verified. Prompt dimensions are design intent only, not measurements of the generated pixels.
- `runtime_approved:false`.

Files:
- `source_original.png`: untouched 1024×1536 RGBA source.
- `checkerboard_review.jpg`: QA composite only; not an asset source.
- `prompt.txt`, `qa_report.json`, `manifest.json`: provenance and review record.
