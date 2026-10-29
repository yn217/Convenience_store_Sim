# Soft-serve machine candidate v1

Standalone soft-serve dispenser for Issue #131. The image contains one cream/stainless appliance with two flavor indicators, a dispensing handle/nozzle and drip tray. Target contract from `data/fixtures/mvp_v1.json`: footprint 1×1m, body height 1.5m, access edge E/+X.

## QA

The category is clear and the machine is a single object. True RGBA is present, but low-alpha haze reaches both horizontal canvas edges; the metallic finish is glossier than the reference game. Projection and exact dimensions are not established; no Godot-size comparison exists. Keep review-only; do not crop/stretch/clean edges or promote to runtime.
