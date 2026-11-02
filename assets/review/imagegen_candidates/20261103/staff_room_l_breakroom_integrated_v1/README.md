# Staff room L — ImageGen review candidate

One new large staff-room asset for the existing `staff_room_l` fixture type. The S and M candidates already exist; this is a separate 4×3 L candidate, not a stretched M image. The game screenshot at `C:/Users/yuuna/Downloads/image-1792819026698.webp` was supplied as a style reference only.

- Original: 1536×1024 RGBA, 1948959 bytes, SHA-256 `aea0b3e17e15c8f3861cd9f90f5b70a8741286658ff2426c642c8fe8e95a5070`; preserved unchanged.
- Fixture contract: 4×3 tiles, 3.92×2.92×2.4m, south access, capacity 10 (copied from `data/fixtures/mvp_v1.json`). These values have not been calibrated to the image.
- Visual QA: break-room function is recognizable, but only nine locker doors are visible; chair capacity and the required 4:3 floor ratio are unverified.
- Style/alpha: glossy product-render finish and dark vignette fail the target style. Alpha margins are below 12% on all edges; see `manifest.json`.
- Projection, world anchor, access clearance, exact scale and Godot render are unverified. No stretching or runtime integration.
- `runtime_approved:false`; review only.
