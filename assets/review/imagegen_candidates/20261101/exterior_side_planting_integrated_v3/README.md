# Side planting strip v3 — review only

This revises the unresolved side planting asset from Issue #163. The original ImageGen RGBA is preserved unchanged. A separate 288px padded sprite was made without resampling; its checkerboard image is only a QA preview.

The tall retaining-wall block from v2 is reduced to a narrow edge and continuous greenery, but the visual slope still estimates only about 0.27 rise/run versus the 0.5 iso2x target. The source alpha margins are under 12%, bright green edge fringe remains, and the style is more photographic than the game. World endpoints, wall occlusion, dimensions and Godot placement are unverified. Do not stretch the image to force a match.

See `prompt.txt`, `asset_candidate.json` and `qa_report.json`. `runtime_approved:false`.
