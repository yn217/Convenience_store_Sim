# Entrance-direction background QA

## Capture setup

- Engine: Godot 4.7.2.stable.official.ed1daf0bf
- Source: `tools/capture_screen.gd`, direct `StoreViewport` capture (`--world-only`)
- Layout: empty fixture plan, normal exterior decorations, calm arrival rate, fit-whole camera
- Day captures: 12:00
- Direction matrix: all four entrance sides for 12×10, 16×12, and 20×16 at 1600×900
- Pan matrix: 20×16, all four entrance sides, zoom 0.5, pan +160/−120 at 1920×1080
- Resolution samples: 12×10 at 1280×720, 16×12 at 1600×900, 20×16 at 1920×1080
- Night sample: 20×16 at 22:00, 1920×1080
- `capture-manifest.json` records pixel dimensions, byte sizes, and SHA-256 for the 20 top-level PNGs.

## Contact sheets

- [All store sizes and entrance directions, daytime](entrance-direction-size-contact-1600x900-day.png)
- [20×16 at zoom 0.5 and pan +160/−120, all entrance directions](20x16-panzoom05-entrance-contact-1920x1080.png)
- Full-size raw captures use the same filename convention: `<width>x<height>-<side>-<resolution>-<day|night>.png`.

## Findings

The background covers all three store footprints and remains visible during the tested pan in each entrance orientation. The detached horizontal east-side planting strip does not appear.

The entrance-side road and parking change sides with the entrance. Residential streets and parked scenery baked into the neighborhood image stay fixed. At north, east, and west entrances, the fixed and dynamic road compositions compete or appear doubled around the store. The south-facing entrance is the closest to the supplied target because its active frontage road aligns with the intended foreground composition.

At 22:00, the neighborhood darkens with the game lighting while the store floor and wall remain bright. The background still has substantially more painterly detail than the store, and the road/layout clash remains. These captures verify rendering coverage and camera movement; they do not pass the final visual-quality gate.

The large-store west entrance was already active, so its move returned `entrance_unchanged`; that capture still exercises the west-side configuration. The other 11 entrance moves returned success.
