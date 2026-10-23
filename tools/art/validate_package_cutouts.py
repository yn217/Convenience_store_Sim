"""Validate and preview transparent package staging candidates."""
from pathlib import Path
import json

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "assets/source/textures/packages/candidates"
REPORT = ROOT / "assets/source/textures/packages/CUTOUT_VALIDATION.json"
PREVIEW = ROOT / "docs/art/package_cutout_zoom_preview.png"


def main() -> int:
    paths = sorted(INPUT.glob("*_cutout_v02.png"))
    errors = []
    records = []
    for path in paths:
        with Image.open(path) as image:
            if image.mode != "RGBA":
                errors.append(f"{path.name}: mode {image.mode} is not RGBA")
            alpha = image.getchannel("A")
            bbox = alpha.getbbox()
            if bbox is None:
                errors.append(f"{path.name}: alpha is empty")
                continue
            left, top, right, bottom = bbox
            if bottom != image.height:
                errors.append(f"{path.name}: visible object does not reach bottom contact edge ({bottom}/{image.height})")
            if left == 0 or right == image.width:
                errors.append(f"{path.name}: alpha touches horizontal canvas edge")
            records.append({"file": str(path.relative_to(ROOT)), "mode": image.mode, "size": list(image.size), "alpha_bbox": list(bbox), "alpha_extrema": list(alpha.getextrema())})
    REPORT.write_text(json.dumps({"status": "PASS" if not errors else "FAIL", "candidate_count": len(records), "errors": errors, "candidates": records}, indent=2) + "\n", encoding="utf-8")

    cell_w, cell_h = 360, 420
    sheet = Image.new("RGBA", (cell_w * 3, cell_h * len(paths)), "#d9dde0")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for row, path in enumerate(paths):
        with Image.open(path).convert("RGBA") as image:
            for col, scale in enumerate((0.5, 1.0, 2.0)):
                scaled = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
                max_w, max_h = cell_w - 12, cell_h - 34
                scaled.thumbnail((max_w, max_h), Image.Resampling.LANCZOS)
                x = col * cell_w + (cell_w - scaled.width) // 2
                y = row * cell_h + 24 + (max_h - scaled.height) // 2
                sheet.alpha_composite(scaled, (x, y))
                draw.text((col * cell_w + 8, row * cell_h + 7), f"{path.stem}  zoom {scale:g}x", fill="#20252b", font=font)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(PREVIEW, format="PNG")
    print(f"cutout validation: {len(records)} files, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
