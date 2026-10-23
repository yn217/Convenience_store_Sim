"""Create common padded customer source canvases without changing originals."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/characters/candidates"
OUT = SOURCE / "source_1024"

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for path in sorted(SOURCE.glob("customer_*_cutout_v01.png")):
        with Image.open(path).convert("RGBA") as image:
            image.thumbnail((960, 1472), Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (1024, 1536), (0, 0, 0, 0))
            canvas.alpha_composite(image, ((1024 - image.width) // 2, (1536 - image.height) // 2))
            target = OUT / path.name.replace("_v01.png", "_source1024_v01.png")
            canvas.save(target)
            print(f"{target.name}: {image.width}x{image.height} on 1024x1536")

if __name__ == "__main__":
    main()
