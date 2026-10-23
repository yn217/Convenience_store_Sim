"""Create a conservative alpha cleanup candidate by removing only near-transparent pixels."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/characters/candidates/source_1024/customer_casual_tote_cutout_source1024_v01.png"
OUT = ROOT / "assets/source/textures/characters/candidates/source_1024/customer_casual_tote_cutout_cleaned_v01.png"

def main() -> None:
    with Image.open(SOURCE).convert("RGBA") as image:
        alpha = image.getchannel("A").point(lambda value: 0 if value < 16 else value)
        image.putalpha(alpha)
        image.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} using alpha threshold 16; geometry unchanged")

if __name__ == "__main__":
    main()
