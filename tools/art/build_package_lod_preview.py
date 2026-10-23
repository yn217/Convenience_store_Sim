"""Build a compact visual comparison sheet for package LOD review."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
LOD = ROOT / "assets/source/textures/packages/candidates/lod"
OUT = ROOT / "docs/art/package_lod_comparison.png"

def main() -> None:
    groups = {}
    for path in sorted(LOD.glob("*_lod_*.png")):
        key = path.name.rsplit("_lod_", 1)[0]
        groups.setdefault(key, []).append(path)
    cell_w, cell_h = 300, 360
    sheet = Image.new("RGBA", (cell_w * len(groups), cell_h), (242, 240, 236, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (key, paths) in enumerate(groups.items()):
        x = index * cell_w
        draw.text((x + 8, 8), key[:34], fill=(30, 30, 30, 255))
        for row, path in enumerate(sorted(paths)):
            with Image.open(path).convert("RGBA") as image:
                image.thumbnail((130, 280), Image.Resampling.NEAREST)
                px = x + 20 + row * 135
                py = 45 + (280 - image.height) // 2
                sheet.alpha_composite(image, (px, py))
                draw.text((px, 330), path.stem.rsplit("_", 2)[-2], fill=(30, 30, 30, 255))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)}: {sheet.width}x{sheet.height}")

if __name__ == "__main__":
    main()
