from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
GEN = Path(r"C:\Users\yuuna\.codex\generated_images\01a16bb7-5a14-77a3-9a09-e07c377b0241")
OUT = ROOT / "docs" / "art"
ASSETS = ROOT / "assets" / "generated" / "props"
VERSION = "painted_v3"

SOURCES = {
    "storefront_window": GEN / "exec-7e314575-67fe-4109-b4d9-ccf856d22d71.png",
    "storefront_wall": GEN / "exec-cf5c7370-8188-47fc-8a1d-93001482ca86.png",
    "storefront_door": GEN / "exec-6af9bb18-6db5-4b3a-939f-cf30165e6d7d.png",
}


def fit_texture(texture: Image.Image, guide: Image.Image) -> Image.Image:
    alpha = guide.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        raise ValueError("guide has no alpha")
    target = (bbox[2] - bbox[0], bbox[3] - bbox[1])
    texture = texture.convert("RGB")
    texture.thumbnail(target, Image.Resampling.LANCZOS)
    texture = texture.resize(target, Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", guide.size, (0, 0, 0, 0))
    x = bbox[0] + (target[0] - texture.width) // 2
    y = bbox[1] + (target[1] - texture.height) // 2
    layer.alpha_composite(texture.convert("RGBA"), (x, y))
    layer.putalpha(alpha)
    return layer


def manifest(asset: str) -> dict:
    data = json.loads((ASSETS / asset / f"{asset}.visual.json").read_text(encoding="utf-8"))
    data["visual_id"] = f"{asset}_{VERSION}"
    data["variant"] = VERSION
    data["runtime_approved"] = False
    for rotation in data["rotations"].values():
        for layer, filename in rotation["layers"].items():
            rotation["layers"][layer] = filename.replace(f"{asset}_", f"{asset}_{VERSION}_")
    return data


def write_provenance(asset: str, source: Path) -> None:
    folder = ASSETS / asset
    body_files = [f"{asset}_{VERSION}_{d}_body.png" for d in range(4)]
    hashes = {name: hashlib.sha256((folder / name).read_bytes()).hexdigest()[:16] for name in body_files}
    data = {
        "asset_id": f"{asset}_{VERSION}",
        "source_type": "AI texture applied to existing project geometry",
        "tool": "OpenAI built-in image_gen",
        "source_texture": f"{asset}_painted_v3_source.png",
        "source_generation_file": str(source),
        "prompt_summary": {
            "window": "flat front-on bright convenience-store interior through glass; generic products and lights",
            "wall": "flat front-on blue/white fascia with fictional name ミニマート青葉",
            "door": "flat front-on cool glass with fictional OPEN 24時間 decal",
        }[asset.split("_")[-1]],
        "application": "Existing storefront piece alpha geometry and iso2x_v1 canvas/anchor retained; texture fitted inside guide silhouette for all four directions.",
        "generation_date": "2026-10-24",
        "runtime_approved": False,
        "sha256_16": hashes,
        "license_or_usage_terms": "AI-generated project asset; fictional generic signage only; no real brands or logos.",
    }
    (folder / "PROVENANCE.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for asset, source in SOURCES.items():
        folder = ASSETS / asset
        texture = Image.open(source).convert("RGB")
        shutil.copy2(source, folder / f"{asset}_{VERSION}_source.png")
        for direction in range(4):
            guide = Image.open(folder / f"{asset}_{direction}_body.png").convert("RGBA")
            fit_texture(texture, guide).save(folder / f"{asset}_{VERSION}_{direction}_body.png")
        (folder / f"{asset}_{VERSION}.visual.json").write_text(json.dumps(manifest(asset), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        write_provenance(asset, source)

    # Light-background contact: old/v3 per direction, storefront pieces only.
    board = Image.new("RGBA", (1400, 3 * 260), (246, 246, 242, 255))
    from PIL import ImageDraw
    draw = ImageDraw.Draw(board)
    for row, asset in enumerate(SOURCES):
        folder = ASSETS / asset
        draw.text((10, row * 260 + 8), f"{asset}  old / painted_v3", fill=(20, 30, 40, 255))
        for direction in range(4):
            old = Image.open(folder / f"{asset}_{direction}_body.png").convert("RGBA")
            new = Image.open(folder / f"{asset}_{VERSION}_{direction}_body.png").convert("RGBA")
            old.thumbnail((150, 210)); new.thumbnail((150, 210))
            x = 190 + direction * 290
            board.alpha_composite(old, (x, row * 260 + 35))
            board.alpha_composite(new, (x + 155, row * 260 + 35))
            draw.text((x + 50, row * 260 + 238), f"d{direction}", fill=(40, 50, 60, 255))
    OUT.mkdir(parents=True, exist_ok=True)
    board.save(OUT / "storefront_painted_v3_contact.png")

    # Six-piece storefront row on pavement-colour background.
    row = Image.new("RGBA", (6 * 220, 360), (113, 122, 126, 255))
    draw = ImageDraw.Draw(row)
    sequence = ["storefront_window", "storefront_window", "storefront_door", "storefront_window", "storefront_wall", "storefront_wall"]
    for index, asset in enumerate(sequence):
        image = Image.open(ASSETS / asset / f"{asset}_{VERSION}_0_body.png").convert("RGBA")
        image.thumbnail((210, 330))
        row.alpha_composite(image, (index * 220 + (210 - image.width) // 2, 15))
    row.save(OUT / "storefront_painted_v3_row.png")


if __name__ == "__main__":
    main()
