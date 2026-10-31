"""Composite four generated continuous merch bands onto the fixed shelf guide."""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("merch_sheet", type=Path)
    ap.add_argument("output_dir", type=Path)
    ap.add_argument(
        "--guide-dir",
        type=Path,
        default=Path("assets/review/guided_assets/shelf_general_open_r0_v1"),
    )
    ap.add_argument(
        "--depth-offsets-m",
        type=float,
        nargs="+",
        default=[-0.28, -0.14, 0.0],
        help="Back-to-front merchandise rows within each shelf board.",
    )
    args = ap.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    guide_path = args.guide_dir / "guide.json"
    region_path = args.guide_dir / "product_front_regions_v1.json"
    guide = json.loads(guide_path.read_text(encoding="utf-8"))
    regions = json.loads(region_path.read_text(encoding="utf-8"))
    if regions.get("source_guide_sha256") != digest(guide_path):
        raise SystemExit("Product regions and geometry guide do not match")
    base_path = args.guide_dir / "empty_corrected.png"
    base = np.array(Image.open(base_path).convert("RGBA"))
    if base.shape[:2] != (640, 640) or len(regions["rows"]) != 4:
        raise SystemExit("Expected 640x640 fixed base and exactly four guide rows")

    sheet = np.array(Image.open(args.merch_sheet).convert("RGBA"))
    nlabels, labels, stats, _ = cv2.connectedComponentsWithStats(
        (sheet[:, :, 3] > 8).astype(np.uint8), 8
    )
    bands = []
    for label in range(1, nlabels):
        x, y, w, h, area = map(int, stats[label])
        if area > 1000:
            bands.append((y, x, label, x, y, w, h, area))
    bands.sort(key=lambda b: (b[0], b[1]))
    if len(bands) != 4:
        raise SystemExit(f"Expected four continuous merchandise strips; found {len(bands)}")

    result = Image.fromarray(base)
    mappings = []
    # Guide row 0 is the bottom board; source strips are ordered top to bottom.
    for guide_index, row in enumerate(regions["rows"]):
        src_band = bands[3 - guide_index]
        _, _, label, x, y, w, h, area = src_band
        art = sheet[y : y + h, x : x + w].copy()
        art[labels[y : y + h, x : x + w] != label, 3] = 0

        slots = row["slots"]
        first = np.asarray(slots[0]["source_quad_px"], dtype=np.float32)
        last = np.asarray(slots[-1]["source_quad_px"], dtype=np.float32)
        # One continuous strip fills the full row; it is not split into individual cards.
        dst = np.float32([last[2], first[3], first[0], last[1]])
        src = np.float32([[0, 0], [w - 1, 0], [w - 1, h - 1], [0, h - 1]])
        board_part = next(part for part in guide["parts"] if part["name"] == row["board"])
        board_min_x, board_max_x = board_part["bounds_m"][0], board_part["bounds_m"][3]
        front_x = slots[0]["world_front_quad"][0][0]
        for depth_index, offset_m in enumerate(args.depth_offsets_m):
            if not board_min_x <= front_x + offset_m <= board_max_x:
                raise SystemExit(f"Merchandise row leaves {row['board']} bounds")
            delta = np.asarray(guide["source_axis_vectors"][0], dtype=np.float32) * offset_m
            shifted_dst = dst + delta
            # Shift the repeated continuous band horizontally to vary the visible pack sequence.
            shifted_art = np.roll(art, shift=(depth_index * max(1, w // 4)), axis=1)
            matrix = cv2.getPerspectiveTransform(src, shifted_dst)
            warped = cv2.warpPerspective(
                shifted_art,
                matrix,
                (640, 640),
                flags=cv2.INTER_LINEAR,
                borderMode=cv2.BORDER_CONSTANT,
                borderValue=(0, 0, 0, 0),
            )
            result = Image.alpha_composite(result, Image.fromarray(warped))
            mappings.append(
                {
                    "board": row["board"],
                    "source_strip_top_to_bottom": 3 - guide_index,
                    "depth_index_back_to_front": depth_index,
                    "world_x_m": round(front_x + offset_m, 6),
                    "source_bbox": [x, y, x + w, y + h],
                    "continuous_alpha_area_px": area,
                    "target_quad_px": shifted_dst.tolist(),
                    "method": "one continuous strip homography to a translated guide row",
                }
            )

    # Restore the existing visible fixture lips and uprights above the merchandise.
    fixture = np.array(Image.open(base_path).convert("RGBA"))
    rgb = fixture[:, :, :3].astype(np.float32)
    teal = (
        (rgb[:, :, 1] > rgb[:, :, 0] * 1.25)
        & (rgb[:, :, 2] > rgb[:, :, 0] * 1.25)
        & (fixture[:, :, 3] >= 128)
    )
    restore = cv2.dilate(teal.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    output = np.array(result)
    output[restore] = fixture[restore]
    result = Image.fromarray(output)

    candidate = args.output_dir / "full_composite_candidate.png"
    result.save(candidate)
    preview = Image.new("RGBA", (1280, 680), (224, 230, 232, 255))
    preview.alpha_composite(Image.fromarray(base), (0, 24))
    preview.alpha_composite(result, (640, 24))
    draw = ImageDraw.Draw(preview)
    draw.text((12, 6), "FIXED EMPTY BASE", fill=(18, 36, 52, 255))
    draw.text((652, 6), "FOUR CONTINUOUS GUIDE-SLOTTED BANDS", fill=(18, 36, 52, 255))
    preview.convert("RGB").save(args.output_dir / "comparison.png")

    alpha = np.array(result.getchannel("A"))
    bbox = Image.fromarray((alpha >= 128).astype(np.uint8) * 255).getbbox()
    report = {
        "asset_id": "shelf_general_open_r0_guided_FULL_continuous_bands_v1",
        "production_method": "ImageGen continuous merch strips + per-row guide homography",
        "source_sheet_sha256": digest(args.merch_sheet),
        "guide_sha256": digest(guide_path),
        "regions_sha256": digest(region_path),
        "fixture_base_sha256": digest(base_path),
        "output_sha256": digest(candidate),
        "canvas_px": [640, 640],
        "anchor_px": guide["anchor_px"],
        "footprint": guide["footprint"],
        "access_edges": guide["sales_face"],
        "continuous_merch_strip_count": len(mappings),
        "facings_per_shelf_depth": len(args.depth_offsets_m),
        "depth_offsets_m_back_to_front": args.depth_offsets_m,
        "guide_sales_row_count": 4,
        "alpha_bbox_ge_128": list(bbox) if bbox else None,
        "fixture_source_preserved": True,
        "individual_item_card_placement": False,
        "runtime_approved": False,
        "qa": {
            "source_row_categories_top_to_bottom": ["snacks", "snacks", "instant_noodle", "bread"],
            "guide_assignment_bottom_to_top": ["bread", "instant_noodle", "snacks", "snacks"],
            "projection": "Each continuous strip is mapped to one guide-derived row quadrilateral; Godot comparison remains pending.",
            "visual_review": "pending",
            "limitations": [
                "homography may soften fine package detail at 640x640",
                "source strips contain repeated package artwork and are not SKU/inventory mappings",
                "fixture base still requires independent reference-shape approval",
            ],
            "status": "review_only",
        },
        "rows": mappings,
    }
    (args.output_dir / "composite_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({"rows": len(mappings), "bbox": bbox, "sha256": report["output_sha256"], "runtime_approved": False}))


if __name__ == "__main__":
    main()
