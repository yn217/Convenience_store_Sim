# Issue #154 character UI mockup

This directory contains one visual proposal for the Issue #154 regional-map
screen where the store manager explains candidate plots and nearby demand
signals.

## Scope

- `issue154_kakogawa_map_rikka.png` is a static design reference for the
  fictionalized Kakogawa-area map and plot-selection screen.
- Koharu Rikka is placed beside the map as a guide; the map pins and right-side
  comparison panel remain the primary interaction surface.
- The intended information architecture is: map, railway/river/POI context,
  candidate plots, location comparison, predicted visitors, time-of-day wave,
  nearby facilities, estimated cost, and confirmation.
- The image is a fictionalized concept map, not a GIS layer or GPS source.
- This asset does not implement map coordinates, pan/zoom, plot selection,
  demand calculation, save/load, or store placement.
- It must not be interpreted as granting cash, reputation, inventory, or any
  other runtime reward.

## Generation provenance

Generated locally with ComfyUI using `Anima-Base-v1.0.safetensors`,
`Koharu-Koharu-epoch100.safetensors`, and
`anima-style-epoch35-lr5e5.safetensors` at LoRA strength 0.8 each. The image
is a visual mockup only; Japanese UI text is not a runtime text source.

