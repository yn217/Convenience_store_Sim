# Character visual pilot

This folder contains the 11 candidates selected for Issue #230's pilot review.

- `title_background_pilot.png`: title-screen background candidate
- three full-body candidates for tutorial/achievement review
- three bust-up reaction candidates
- three function-linked pose candidates
- one daily-event candidate

The files are intentionally kept separate from the 334-image review pool. They are not marked `runtime_approved` yet, and the review scene must be used before any production UI replacement. The source-to-trigger mapping is [character_visuals_v1.json](../../../data/presentation/character_visuals_v1.json).

The seven standing-image entries have a derived copy under `derived_alpha/`. Only edge-connected white background pixels are removed; the original PNGs remain unchanged for comparison and rollback. The Godot pilot panel uses these derived paths and keeps the legacy presentation as fallback.
