# ImageGen prompt notes

## Hot-snack case v1
"One isolated transparent 2D game sprite of a compact three-bay Japanese convenience store hot-snack warmer, fried chicken, croquettes, nikuman behind clear front glass. Polished hand-painted isometric tycoon game illustration, warm internal glow, stainless frame, low long countertop case, thin top rim, no roof or broad solid top slab. Three-quarter view showing long customer-facing front and right end. Classic 2:1 isometric axes, parallel edges, no perspective convergence. One asset only; no text, labels, logos, room, counter, people, or cast shadow outside footprint."

## Projection edit v2
Image-to-image edit of v1. Preserve the same three compartments, foods, case, and style; change camera only to orthographic 2:1 isometric. Require the long front edge to have 1:2 vertical-to-horizontal slope, depth edges opposite slope, vertical supports vertical. Transparent, entire object with margin.

## Open snack gondola v1
"One complete open ambient gondola shelf with merchandise already naturally stocked on every shelf; not separate product icons or an atlas. Freestanding open-back Japanese convenience-store center gondola, one-sided display candidate, four shallow shelves, slim metal uprights, narrow price rails, low dark base, densely and naturally stocked with upright colorful snack bags and slim cartons, printed fronts facing customer. Polished hand-painted 2D game illustration. Strict orthographic 2:1 isometric axes, long front edge diagonal down-right 1 vertical per 2 horizontal pixels, depth edge opposite, uprights vertical, no perspective convergence. 1-by-2 tile silhouette, shallow boards, packages at front edge, no roof. Transparent, one asset only, no logos/text/people/background/collage/cubes/detached product cards."

## Open gondola style-reference prompt

Used `C:\Users\yuuna\Downloads\image-1792819026698.webp` as a style/camera reference only. Requested one integrated stocked open snack gondola, no roof, dense fronts, transparent background, 2:1 orthographic game isometric axes, and no product cards/cubes. Generated image remains untouched. See `open_snack_gondola_style_ref_candidate_v2.png`.

## Small tabletop oden warmer prompt notes

Generated one requested small countertop warmer, 3–4 broth divisions, daikon/egg/tofu/konjac/fish cake, clear sneeze guard, short stainless base/control, approx. 0.45×0.35×0.35 m, with the supplied game screenshot used for art style. v2 edits only the camera toward elevated orthographic 2:1 iso; v3 edits only framing to request 12% clear margin. Generation did not establish exact world projection. See `qa.json` for hashes and alpha bounds.

## Bakery gondola prompt note

Generated two integrated shelf-plus-bread images using the game screenshot as a style reference. v1 requested one-sided four-row shallow trays; v2 additionally specified 2.0×1.0×1.5m, a width:height sprite ratio near 0.90:1, exact opposing 2:1 screen-axis slopes, four shelves, no roof, and margin. Image generation did not satisfy all projection/margin constraints. See `qa.json` for measured alpha boxes, aspect, hashes, and visual findings.
