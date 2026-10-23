"""Build review-only package LODs from normalized transparent cutouts."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/textures/packages/candidates"
OUT = SOURCE / "lod"

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    outputs = []
    for source in sorted(SOURCE.glob("*_cutout_v02.png")):
        with Image.open(source).convert("RGBA") as image:
            for label, scale in (("lod_0_5", 0.5), ("lod_0_25", 0.25)):
                size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
                target = OUT / f"{source.stem}_{label}.png"
                image.resize(size, Image.Resampling.LANCZOS).save(target)
                outputs.append({"source": source.relative_to(ROOT).as_posix(), "path": target.relative_to(ROOT).as_posix(), "scale": scale, "dimensions": list(size), "mode": "RGBA"})
                print(f"{target.name}: {size[0]}x{size[1]}")
    (OUT / "LOD_MANIFEST.json").write_text(__import__("json").dumps({"status": "review-only; not runtime wired", "outputs": outputs}, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
