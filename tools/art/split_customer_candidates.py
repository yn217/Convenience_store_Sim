"""Split the three-column customer concept board into review candidates."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/characters/customer_variants_comparison_v01.png"
OUT = ROOT / "assets/source/textures/characters/candidates"

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE).convert("RGBA") as image:
        width, height = image.size
        for index, name in enumerate(("casual_tote", "office_shoulder_bag", "older_basket")):
            left = round(index * width / 3)
            right = round((index + 1) * width / 3)
            crop = image.crop((left, 0, right, height))
            crop.save(OUT / f"customer_{name}_candidate_v01.png")
            print(f"{name}: {crop.width}x{crop.height}")

if __name__ == "__main__":
    main()
