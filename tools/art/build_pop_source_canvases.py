"""Build 256x256 staging canvases for the two POP candidates."""
from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "assets/source/textures/pop/candidates"
OUTPUT = INPUT / "source_256"


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for source in sorted(INPUT.glob("*_cutout_v02.png")):
        with Image.open(source).convert("RGBA") as image:
            scale = min(224 / image.width, 224 / image.height, 1.0)
            size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
            resized = image.resize(size, Image.Resampling.LANCZOS)
            canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
            x = (256 - resized.width) // 2
            y = 256 - resized.height
            canvas.alpha_composite(resized, (x, y))
            output = OUTPUT / source.name.replace("_cutout_v02.png", "_source256_v01.png")
            canvas.save(output, format="PNG", optimize=False)
            records.append({"source": str(source.relative_to(ROOT)), "output": str(output.relative_to(ROOT)), "canvas_px": [256, 256], "anchor_px": [x + resized.width // 2, 256]})
    (OUTPUT / "SOURCE_CANVAS_MANIFEST.json").write_text(json.dumps({"status": "source staging only", "candidates": records}, indent=2) + "\n", encoding="utf-8")
    print(f"built {len(records)} POP source canvases")


if __name__ == "__main__":
    main()
