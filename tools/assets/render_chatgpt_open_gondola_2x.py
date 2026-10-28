#!/usr/bin/env python3
"""Render the registered ChatGPT open-gondola SVGs at 2x with a tiny X-axis fit.

The SVG sources remain untouched. The transform corrects only the measured outer
base width from 0.91 m to the 0.92 m fixture contract, around the ground pivot.
"""

from __future__ import annotations

import json
import io
import math
import re
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree as ET

import cairosvg
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = ROOT / "assets/source/chatgpt_2d_interior/shelf_general_open_r0_v1"
EXPECTED_OUTER_X_M = 0.92
MEASURED_OUTER_X_M = 0.91
X_SCALE = EXPECTED_OUTER_X_M / MEASURED_OUTER_X_M
PIVOT_SVG = (205.72, 445.63)
STATES = ("empty", "half", "full")
RENDER_STATES = ("empty",)
REVIEW_DIR = ASSET_DIR / "review"


def transform_svg(source: bytes, scale_x_world: float) -> tuple[bytes, tuple[float, ...]]:
    root = ET.fromstring(source)
    children = list(root)
    if not children:
        raise ValueError("SVG contains no artwork")

    # Convert a world-X-only scale into iso2x screen coordinates, preserving
    # the +/-26.565 degree projected axis slopes and fixing the ground pivot.
    d = scale_x_world - 1.0
    a = 1.0 + 0.5 * d
    b = 0.25 * d
    c = d
    e_diag = a
    px, py = PIVOT_SVG
    e = px - a * px - c * py
    f = py - b * px - e_diag * py
    matrix = (a, b, c, e_diag, e, f)

    group = ET.Element("{http://www.w3.org/2000/svg}g", {
        "transform": "matrix(" + " ".join(f"{v:.12f}" for v in matrix) + ")"
    })
    for child in children:
        root.remove(child)
        group.append(child)
    root.append(group)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True), matrix


def parse_viewbox(svg: bytes) -> tuple[float, float]:
    root = ET.fromstring(svg)
    values = [float(v) for v in re.split(r"[ ,]+", root.attrib["viewBox"].strip())]
    return values[2], values[3]


def structural_vector_counts() -> dict[str, object]:
    counters: dict[str, Counter[str]] = {}
    for state in STATES:
        source = (ASSET_DIR / f"shelf_general_open_{state}_r0_v1.svg").read_bytes()
        root = ET.fromstring(source)
        counters[state.upper()] = Counter(
            ET.tostring(element, encoding="unicode")
            for element in root.iter()
            if element.tag.rsplit("}", 1)[-1] in ("polygon", "line", "ellipse")
        )
    shared_all = counters["EMPTY"] & counters["HALF"] & counters["FULL"]
    return {
        "exact_matching_vector_elements_all_states": sum(shared_all.values()),
        "vector_elements_by_state": {key: sum(value.values()) for key, value in counters.items()},
        "exact_matches_by_state_pair": {
            "EMPTY_HALF": sum((counters["EMPTY"] & counters["HALF"]).values()),
            "EMPTY_FULL": sum((counters["EMPTY"] & counters["FULL"]).values()),
            "HALF_FULL": sum((counters["HALF"] & counters["FULL"]).values()),
        },
    }


def alpha_metrics(path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        if image.mode != "RGBA":
            raise ValueError(f"{path.name}: expected RGBA, got {image.mode}")
        return alpha_metrics_from_image(image)


def alpha_metrics_from_image(image: Image.Image) -> dict[str, object]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("fully transparent render")
    return {
        "canvas_px": list(image.size),
        "alpha_bbox_px": list(bbox),
        "alpha_bbox_size_px": [bbox[2] - bbox[0], bbox[3] - bbox[1]],
        "alpha_nonzero_pixels": sum(1 for value in alpha.getdata() if value > 0),
    }


def main() -> None:
    manifests: dict[str, str] = {}
    matrices: dict[str, list[float]] = {}
    raw_images: dict[str, Image.Image] = {}
    for state in RENDER_STATES:
        stem = f"shelf_general_open_{state}_r0_v1"
        svg_path = ASSET_DIR / f"{stem}.svg"
        png_path = ASSET_DIR / f"{stem}.png"
        original = svg_path.read_bytes()
        width, height = parse_viewbox(original)
        raw_png = cairosvg.svg2png(
            bytestring=original,
            output_width=round(width * 2),
            output_height=round(height * 2),
        )
        raw_images[state.upper()] = Image.open(io.BytesIO(raw_png)).convert("RGBA")
        transformed, matrix = transform_svg(original, X_SCALE)
        candidate_png = cairosvg.svg2png(
            bytestring=transformed,
            output_width=round(width * 2),
            output_height=round(height * 2),
        )
        png_path.write_bytes(candidate_png)
        manifests[state.upper()] = png_path.name
        matrices[state.upper()] = list(matrix)

    images = {
        state.upper(): alpha_metrics(ASSET_DIR / f"shelf_general_open_{state}_r0_v1.png")
        for state in RENDER_STATES
    }
    if tuple(images["EMPTY"]["canvas_px"]) != (1040, 1080):
        raise ValueError("EMPTY PNG canvas does not match the 2x source contract")

    REVIEW_DIR.mkdir(parents=True, exist_ok=True)
    raw = raw_images["EMPTY"].resize((520, 540), Image.Resampling.LANCZOS)
    calibrated = Image.open(ASSET_DIR / manifests["EMPTY"]).convert("RGBA").resize((520, 540), Image.Resampling.LANCZOS)
    sheet = Image.new("RGB", (1120, 650), "#202a35")
    draw = ImageDraw.Draw(sheet)
    draw.text((24, 15), "ChatGPT source SVG  →  projection-calibrated 2x PNG", fill="#f3f6f8")
    draw.text((24, 43), "Same iso2x_v1 angles; 1.1% short-axis fit around the fixed ground anchor", fill="#b8c5cf")
    for x, title, preview in ((24, "SOURCE (unmodified SVG)", raw), (576, "CALIBRATED OUTPUT", calibrated)):
        draw.text((x, 75), title, fill="#f3f6f8")
        rgba = Image.new("RGBA", preview.size, (255, 255, 255, 255))
        rgba.alpha_composite(preview)
        sheet.paste(rgba.convert("RGB"), (x, 99))
        ax, ay = (int(round(v)) for v in PIVOT_SVG)
        cx, cy = x + ax, 99 + ay
        draw.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), outline="#00a778", width=3)
        draw.line((cx - 10, cy, cx + 10, cy), fill="#00a778", width=2)
        draw.line((cx, cy - 10, cx, cy + 10), fill="#00a778", width=2)
    draw.text((24, 643 - 24), "Green mark = unchanged world ground anchor", fill="#b8c5cf")
    sheet_path = REVIEW_DIR / "projection_calibration_comparison.png"
    sheet.save(sheet_path, optimize=True)

    # The SVG coordinates are 1x artwork coordinates; PNG is exported at 2x.
    anchor_px = [round(PIVOT_SVG[0] * 2, 2), round(PIVOT_SVG[1] * 2, 2)]
    long_angle_raw = math.degrees(math.atan2(122.88, -245.76))
    long_angle_deg = (long_angle_raw + 90.0) % 180.0 - 90.0
    short_angle_deg = math.degrees(math.atan2(56.0, 112.0))
    report = {
        "asset_id": "shelf_general_open_r0_v1",
        "source_svg_modified": False,
        "render": {"scale": 2, "renderer": "CairoSVG", "mode": "RGBA"},
        "projection": {
            "projection_id": "iso2x_v1",
            "long_axis_vector_svg_px": [-245.76, 122.88],
            "long_axis_angle_deg": round(long_angle_deg, 6),
            "long_axis_angle_definition": "undirected screen line angle normalized to [-90, 90) degrees",
            "short_axis_vector_svg_px": [112.0, 56.0],
            "short_axis_angle_deg": round(short_angle_deg, 6),
            "target_axis_angles_deg": [-26.565051, 26.565051],
            "rotation_applied_deg": 0.0,
        },
        "dimensions": {
            "long_axis_m": 1.92,
            "outer_short_axis_before_m": MEASURED_OUTER_X_M,
            "outer_short_axis_target_m": EXPECTED_OUTER_X_M,
            "outer_short_axis_after_m": EXPECTED_OUTER_X_M,
            "outer_short_axis_vector_before_svg_px": [116.48, 58.24],
            "outer_short_axis_vector_after_svg_px": [round(116.48 * X_SCALE, 4), round(58.24 * X_SCALE, 4)],
            "world_x_scale": round(X_SCALE, 9),
            "world_y_scale": 1.0,
            "scale_pivot_svg_px": list(PIVOT_SVG),
        },
        "anchor_px_2x": anchor_px,
        "empty_source_render": alpha_metrics_from_image(raw_images["EMPTY"]),
        "states": images,
        "state_geometry_comparison": structural_vector_counts(),
        "approval": {
            "shape_approved": False,
            "visual_qa_passed": False,
            "godot_runtime_verified": False,
            "runtime_approved": False,
        },
        "files": {"png": manifests, "transform_matrix_svg": matrices},
        "review_sheet": "review/projection_calibration_comparison.png",
        "notes": [
            "Only the already registered ChatGPT SVG artwork was rasterized; no new art was generated.",
            "A 1.1% world-X-only scale was applied to the output render to fit the 0.92 m outer footprint; source SVGs remain unchanged.",
            "Projected axis angles already matched iso2x_v1; no angle rotation was needed.",
            "Only EMPTY was exported before the P0 shape gate; FULL/HALF PNG export is deferred until EMPTY approval.",
            "Art-form and Japanese retail visual approval remain open under issues #157/#123.",
        ],
    }
    (ASSET_DIR / "projection_qa.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"files": manifests, "metrics": images, "review_sheet": str(sheet_path), "report": str(ASSET_DIR / 'projection_qa.json')}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
