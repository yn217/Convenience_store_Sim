# Copier multifunction unit — review candidate

Codex ImageGen generated an isolated 2D copier sprite. A prior attempted generation returned a full convenience-store scene and was excluded; `source_original.png` is the single-object result from the isolated re-prompt. The source PNG is retained byte-for-byte. Only review padding and a checkerboard composite are derived.

Fixture contract reference: `copier` is nominally 1x1 tile, 0.92 x 0.92 x 1.20 m, access edge S. This is not a calibrated implementation or runtime sprite. Review required before use.

`runtime_approved:false`; no Godot renderer changes or runtime integration.
