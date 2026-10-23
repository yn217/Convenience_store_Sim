# UI icons (assets/ui/icons)

Provenance: all 25 icons are original SVG drawings made for this project (Issue #61, Phase E). They are hand-written
geometry (rectangles, circles, paths) with no third-party artwork, no traced images, no fonts, no logos and no trademarks.
License: the project license (see the repository root). Redistribution: yes.

- Format: SVG, 24 x 24 viewBox, one colour `#ffffff` so Godot tints them with `modulate` or icon colour overrides.
- Loading: `scripts/presentation/ui_icons.gd` reads the SVG text and rasterises it at the requested size
  (`UiIcons.texture(name, size)`), so no `.import` sidecar is needed.
- Names: store, box, person, megaphone, bar-chart, gear, cash, wallet, users, sun, chevron-right, trash, rotate,
  move, heart, calendar, music-note, drop, eye, cart, truck, tag, grid, play, pause.

The ledger row is in `docs/ASSET_CREDITS.md`.
