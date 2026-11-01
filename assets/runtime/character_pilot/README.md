# Character visual pilot

This folder contains the 48 candidates selected for Issue #230's pilot review.

- `title_background_pilot.png`: title-screen background candidate
- three full-body candidates for tutorial/achievement review
- three bust-up reaction candidates
- thirty function-linked pose candidates
- eleven daily-event candidates (the quiet-street event uses a bust-up reaction candidate)

The files are intentionally kept separate from the 334-image review pool. They are not marked `runtime_approved` yet, and the review scene must be used before any production UI replacement. The source-to-trigger mapping is [character_visuals_v1.json](../../../data/presentation/character_visuals_v1.json).

The forty-four standing-image entries and three bust-up reactions have derived copies under `derived_alpha/`. These copies are generated with ComfyUI's built-in BiRefNet background-removal model and an inverted foreground mask; the original PNGs remain unchanged for comparison and rollback. The reprocessing workflows are `tools/assets/apply_birefnet_character_pilot.ps1` and `tools/assets/apply_birefnet_event_candidates.ps1`. The Godot pilot panel uses these derived paths and keeps the legacy presentation as fallback.

The order and restock actions, staff screen, save completion, staff hiring, and promotion-start cues briefly show their functional pilot figure above the management window. Other assistant story lines retain the existing screen-suppression behavior.
