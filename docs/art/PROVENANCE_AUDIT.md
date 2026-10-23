# Provenance path audit (Issue #29)

`tools/art/validate_provenance_paths.py` checks every `assets/...` path recorded in `*PROVENANCE.json` files and fails when a referenced file is absent.

This is a path-integrity check only. It does not approve licenses, trademarks, generated text, model identity, or runtime adoption. Those remain explicitly pending human review where the provenance records say so.
