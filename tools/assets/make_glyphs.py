"""Filled UI glyphs for the 2026-11-01 mockup look (the menu, the tabs, the top and bottom bars): solid white shapes on a
24x24 viewBox, tinted by the game (MockStyle.glyph). Written by hand, no external art.

    python tools/assets/make_glyphs.py     # -> assets/ui/glyphs/<name>.svg
"""
from pathlib import Path

OUT = Path("assets/ui/glyphs")
W = 'fill="#ffffff"'
GLYPHS = {
    "home": f'<path {W} d="M12 2.5 1.8 11h2.7v10h6v-6h3v6h6V11h2.7z"/>',
    "box": f'<path {W} d="M12 2 3 6.2v11.4L12 22l9-4.4V6.2zm0 2.3 6.3 2.9L12 10.1 5.7 7.2zM5 8.8l6 2.8v7.9l-6-2.9zm14 0v7.8l-6 2.9v-7.9z"/>',
    "truck": f'<path {W} d="M1.5 5h12.5v10H1.5zM15 8.5h3.8l3.7 4.2V15H15zM5.5 19.5a2.2 2.2 0 1 1 0-4.4 2.2 2.2 0 0 1 0 4.4zm12 0a2.2 2.2 0 1 1 0-4.4 2.2 2.2 0 0 1 0 4.4z"/>',
    "chart-up": f'<path {W} d="M3 21h18v1.5H3zM4 15h3v5H4zm5-3h3v8H9zm5-2h3v10h-3zM3.5 11.5 9 6.5l3.5 3 5.5-5.2V2h4.5v4.5h-2.3l-7.7 7.3-3.5-3-5 4.6z"/>',
    "bar-chart": f'<path {W} d="M3 20.5h18V22H3zM4 12h3.2v7H4zm5-5h3.2v12H9zm5 3h3.2v9H14zm5-6h3.2v15H19z"/>',
    "users": f'<path {W} d="M9 11.5a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm-7.5 9c0-4 3.2-7 7.5-7s7.5 3 7.5 7zM16.5 11a3.3 3.3 0 1 0-1-6.5 5.4 5.4 0 0 1 0 6.3c.3.1.7.2 1 .2zm1.4 1.8c2.7.7 4.6 3.2 4.6 6.2v1.5h-4.2c0-3.2-1.2-5.8-3.3-7.4.9-.3 1.9-.4 2.9-.3z"/>',
    "person": f'<path {W} d="M12 12a4.6 4.6 0 1 1 0-9.2A4.6 4.6 0 0 1 12 12zm-8.5 9.5c0-4.6 3.8-7.8 8.5-7.8s8.5 3.2 8.5 7.8z"/>',
    "wrench": f'<path {W} d="M21.6 6.4 18 10l-3.6-.4L14 6l3.6-3.6a6 6 0 0 0-7.8 7.6L2.5 17.3a2.4 2.4 0 0 0 3.4 3.4L13.2 13.4a6 6 0 0 0 8.4-7z"/>',
    "trophy": f'<path {W} d="M6 2.5h12v2h3.5v2.5a5 5 0 0 1-4.6 5A6 6 0 0 1 13 15.8V18h3.5v3.5h-9V18H11v-2.2A6 6 0 0 1 7.1 12 5 5 0 0 1 2.5 7V4.5H6zm0 4.1H4.6V7A2.9 2.9 0 0 0 6.4 9.7 9 9 0 0 1 6 6.6zm12 0a9 9 0 0 1-.4 3.1A2.9 2.9 0 0 0 19.4 7v-.4z"/>',
    "gear": f'<path {W} fill-rule="evenodd" d="M10.2 1.5h3.6l.5 2.8 1.9.8 2.3-1.6 2.5 2.5-1.6 2.3.8 1.9 2.8.5v3.6l-2.8.5-.8 1.9 1.6 2.3-2.5 2.5-2.3-1.6-1.9.8-.5 2.8h-3.6l-.5-2.8-1.9-.8-2.3 1.6-2.5-2.5 1.6-2.3-.8-1.9-2.8-.5v-3.6l2.8-.5.8-1.9-1.6-2.3 2.5-2.5 2.3 1.6 1.9-.8zM12 8.3a3.7 3.7 0 1 0 0 7.4 3.7 3.7 0 0 0 0-7.4z"/>',
    "store": f'<path {W} d="M3.5 3h17l2 5.5a2.9 2.9 0 0 1-5.4 1.4 2.9 2.9 0 0 1-5.1 0 2.9 2.9 0 0 1-5.1 0A2.9 2.9 0 0 1 1.5 8.5zM3.5 12.3a4.6 4.6 0 0 0 3.4-.4 4.6 4.6 0 0 0 5.1 0 4.6 4.6 0 0 0 5.1 0 4.6 4.6 0 0 0 3.4.4V21h-6.6v-5.5h-3.8V21H3.5z"/>',
    "crown": f'<path {W} d="M2 7.5l5 4.2L12 3l5 8.7 5-4.2-2 11.5H4zM4.2 20.3h15.6V22H4.2z"/>',
    "moon": f'<path {W} d="M14.5 2.2A9.8 9.8 0 1 0 21.8 15 8 8 0 0 1 14.5 2.2z"/>',
    "cart": f'<path {W} d="M1.5 3h3.2l.8 3H22l-2.4 8.4H7.6l.5 2H20v2H6.6L3.2 5H1.5zM8.5 22a1.8 1.8 0 1 1 0-3.6 1.8 1.8 0 0 1 0 3.6zm9.5 0a1.8 1.8 0 1 1 0-3.6 1.8 1.8 0 0 1 0 3.6z"/>',
    "pencil": f'<path {W} d="M3 17.3V21h3.7L18 9.7 14.3 6zM20.7 7a1 1 0 0 0 0-1.4l-2.3-2.3a1 1 0 0 0-1.4 0l-1.8 1.8L19 8.8z"/>',
    "tag": f'<path {W} fill-rule="evenodd" d="M2 3.5V11l10.5 10.5L21 13 10.5 2.5H3a1 1 0 0 0-1 1zm5 1.5a2 2 0 1 1 0 4 2 2 0 0 1 0-4z"/>',
    "shelf": f'<path {W} d="M3 3h18v18h-2v-2H5v2H3zm2 2v4h14V5zm0 6v6h14v-6zm2 1.5h4v3.5H7zm6-6h4V8h-4z"/>',
    "star": f'<path {W} d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7L12 17.2 5.8 20.9l1.6-7L2 9.2l7.1-.6z"/>',
    "chevron": f'<path {W} d="M8.5 3.5 17 12l-8.5 8.5-2.3-2.3L12.4 12 6.2 5.8z"/>',
    "pause": f'<path {W} d="M6 4h4v16H6zm8 0h4v16h-4z"/>',
    "play": f'<path {W} d="M7 3.5v17L20.5 12z"/>',
    "dot": f'<circle {W} cx="12" cy="12" r="8"/>',
    "arrow-up": f'<path {W} d="M12 2.5 3.5 11h5.3v10.5h6.4V11h5.3z"/>',
    "dashboard": f'<path {W} d="M3 3h8v10H3zm10 0h8v6h-8zM3 15h8v6H3zm10-4h8v10h-8z"/>',
    "calendar": f'<path {W} fill-rule="evenodd" d="M6 1.5h2.5V4h7V1.5H18V4h2a1.5 1.5 0 0 1 1.5 1.5v15A1.5 1.5 0 0 1 20 22H4a1.5 1.5 0 0 1-1.5-1.5v-15A1.5 1.5 0 0 1 4 4h2zM4.5 9v11h15V9zm2 2h3v3h-3zm4.5 0h3v3h-3zm4.5 0h3v3h-3zM6.5 15.5h3v3h-3zm4.5 0h3v3h-3z"/>',
    "box3d": f'<path {W} d="M12 1.8 2.5 6.3 12 10.8l9.5-4.5zM2 7.8v10.5l9 4.4V12.2zm20 0-9 4.4v10.5l9-4.4z"/>',
    "tools": f'<path {W} d="M21.4 5.8 18.3 8.9 15.1 5.7l3.1-3.1a5 5 0 0 0-6.6 6.2L3 17.4a2.2 2.2 0 0 0 3.1 3.1l8.6-8.6a5 5 0 0 0 6.7-6.1zM4.2 2.2 2.2 4.2l4.6 6.2 1.6.2 2.1 2.1 1.4-1.4-2.1-2.1-.2-1.6zm9.6 12.3 6.1 6.1a1.8 1.8 0 0 0 2.5-2.5l-6.1-6.1z"/>',
    "shield": f'<path {W} d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5z"/>',
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, body in GLYPHS.items():
        (OUT / (name + ".svg")).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>\n' % body,
                                          encoding="utf-8")
    print(len(GLYPHS), "glyphs")


if __name__ == "__main__":
    main()
