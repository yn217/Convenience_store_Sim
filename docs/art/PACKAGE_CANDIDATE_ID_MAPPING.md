# Candidate package-to-visual ID mapping

`assets/source/textures/packages/CANDIDATE_VISUAL_ID_MAP.json` records a
review-only mapping from the three representative generated package families
to existing product `visual_id` names from `docs/examples/mvp_v1.products.json`.

The mapping deliberately does not alter the product catalog or runtime
manifest. It provides a reversible handoff for the next stage: select a
variant, perform human mark/text review, render with `iso2x_v1`, and replace a
visual asset through the existing slot-overlay path while retaining the
procedural fallback.
