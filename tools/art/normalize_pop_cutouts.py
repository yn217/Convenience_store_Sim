"""Normalize the two fictional POP cutouts with a bottom contact edge."""
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "assets/source/textures/pop/candidates"
PADDING = 8


def main() -> None:
    count = 0
    for source in sorted(INPUT.glob("*_cutout_v01.png")):
        with Image.open(source).convert("RGBA") as image:
            bbox = image.getchannel("A").getbbox()
            if bbox is None:
                raise ValueError(f"empty alpha: {source}")
            left, top, right, bottom = bbox
            content = image.crop((left, top, right, bottom))
            output_image = Image.new("RGBA", (content.width + PADDING * 2, content.height + PADDING), (0, 0, 0, 0))
            output_image.alpha_composite(content, (PADDING, PADDING))
            output = source.with_name(source.name.replace("_cutout_v01.png", "_cutout_v02.png"))
            output_image.save(output, format="PNG", optimize=False)
            count += 1
    print(f"normalized {count} POP cutouts")


if __name__ == "__main__":
    main()
