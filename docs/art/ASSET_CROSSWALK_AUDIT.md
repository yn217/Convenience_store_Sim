# Asset provenance crosswalk audit (Issue #29)

Generate `ASSET_CROSSWALK_AUDIT.json` with `tools/art/audit_asset_crosswalk.py`.

The report joins provenance path references with the existing product visual IDs and records which IDs have review-only package candidates. It is intentionally conservative: pending license/trademark review and missing 4-direction/runtime evidence remain incomplete, and the report does not authorize runtime adoption.
