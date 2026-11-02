# Staff room M — review candidate only

- Asset ID: `staff_room_m_breakroom_integrated_v1`; fixture `staff_room_m`.
- Registry target: 3×2 tiles, 2.92×1.92×2.4 m, south access, capacity 6. These values are requirements from `data/fixtures/mvp_v1.json`, not image measurements.
- Generated with built-in Codex ImageGen on 2026-11-02. The untouched output is `source_original.png`; prompt is in `prompt.txt`.
- Visual content: three lockers, microwave/hot-drink counter, shared bench/table, clock and bulletin board. An unrequested potted plant and a small waste bin also appear.
- Preliminary review: recognizably larger than the S concept; south/front is open. Checkerboard preview shows a transparent exterior. Independent visual review flags a broad dark outer blur and semitransparent edge. Every nontransparent pixel is semitransparent (alpha max 254, no opaque pixels), so game opacity remains questionable. The near-side opening probably serves as access, but its south orientation is not visible in the image. Iso2x axes, exact 3×2 floor bounds, scale, anchor and Godot display are unverified. Review-only; `runtime_approved:false`.
- Do not use as runtime art until alpha opacity, projection, dimensions, access, anchor and small-zoom readability are reviewed.