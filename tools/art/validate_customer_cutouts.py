"""Focused validation for Issue #23 customer source cutout pilots."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROV = ROOT / "assets/source/textures/characters/CUSTOMER_PROVENANCE.json"
OUT = ROOT / "assets/source/textures/characters/CUSTOMER_CUTOUT_VALIDATION.json"
CHAR_ROOT = PROV.parent

def main() -> None:
    data = json.loads(PROV.read_text(encoding="utf-8"))
    results = []
    problems = []
    for item in data.get("cutouts", []):
        path = ROOT / item["path"] if item["path"].startswith("assets/") else CHAR_ROOT / item["path"]
        result = {"path": item["path"], "expected_dimensions": item["dimensions"], "expected_mode": item["alpha"]}
        if not path.is_file():
            problems.append(f"missing: {item['path']}")
            result["status"] = "missing"
            results.append(result)
            continue
        with Image.open(path) as image:
            alpha = image.getchannel("A")
            bbox = alpha.getbbox()
            padding = None
            if bbox:
                left, top, right, bottom = bbox
                padding = {"left": left, "top": top, "right": image.width - right, "bottom": image.height - bottom}
            result.update({"dimensions": f"{image.width}x{image.height}", "mode": image.mode, "alpha_bbox": list(bbox) if bbox else None, "padding_px": padding, "min_padding_ok": bool(padding and min(padding.values()) >= 8), "edge_alpha": {"left": bool(alpha.crop((0, 0, 1, image.height)).getbbox()), "right": bool(alpha.crop((image.width - 1, 0, image.width, image.height)).getbbox()), "top": bool(alpha.crop((0, 0, image.width, 1)).getbbox()), "bottom": bool(alpha.crop((0, image.height - 1, image.width, image.height)).getbbox())}, "bottom_alpha_row": max((y for y in range(image.height) if alpha.crop((0, y, image.width, y + 1)).getbbox()), default=None)})
            if image.mode != "RGBA":
                problems.append(f"not RGBA: {item['path']}")
            if [image.width, image.height] != [1024, 1536]:
                problems.append(f"unexpected dimensions: {item['path']}")
            if bbox is None:
                problems.append(f"empty alpha: {item['path']}")
            result["status"] = "pass" if result["min_padding_ok"] and not any(result["edge_alpha"].values()) else "needs_human_review"
        results.append(result)
    OUT.write_text(json.dumps({"status": "source-art pilot; anchor and direction still require review", "results": results}, indent=2) + "\n", encoding="utf-8")
    if problems:
        raise SystemExit("\n".join(problems))
    print(f"CUSTOMER CUTOUTS: PASS - {len(results)} RGBA pilots; bottom contact is reported, not approved")

if __name__ == "__main__":
    main()
