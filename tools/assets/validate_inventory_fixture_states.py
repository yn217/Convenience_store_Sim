"""Focused validation for Issue #91 Blender inventory-state candidates."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

EXPECTED_PROJECTION = {
    "marker_x": (128.0, 64.0, 1.0),
    "marker_y": (-128.0, 64.0, 1.0),
    "marker_z": (0.0, -156.76734354, 2.0),
}


def centroid(mask, weights):
    ys, xs = np.nonzero(mask)
    if not len(xs):
        raise ValueError("calibration marker not found")
    w = weights[ys, xs]
    return [float(((xs + 0.5) * w).sum() / w.sum()), float(((ys + 0.5) * w).sum() / w.sum())]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    base = args.candidate
    manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    provenance = json.loads((base / "provenance.json").read_text(encoding="utf-8"))
    calibration = np.asarray(Image.open(base / "calibration.png").convert("RGBA"), dtype=np.float64)
    r, g, b, alpha = (calibration[..., i] for i in range(4))
    masks = {
        "marker_o": (r > 220) & (g > 220) & (b > 220) & (alpha > 200),
        "marker_x": (r > 200) & (g < 60) & (b < 60) & (alpha > 200),
        "marker_y": (g > 200) & (r < 60) & (b < 60) & (alpha > 200),
        "marker_z": (b > 200) & (r < 60) & (g < 60) & (alpha > 200),
    }
    centers = {key: centroid(mask, alpha) for key, mask in masks.items()}
    origin = centers["marker_o"]
    projection = {}
    errors = []
    fixture = manifest["fixture_type_id"]
    if set(manifest.get("states", {})) != {"FULL", "HALF", "EMPTY"}:
        errors.append("manifest must contain exactly FULL/HALF/EMPTY states")
    expected_product_shapes = {
        "fridge_drink": {"bottle_500": [0.068, 0.068, 0.225]},
        "shelf_noodle": {"cup_noodle": [0.110, 0.110, 0.120]},
        "shelf_general": {"snack_pouch": [0.130, 0.055, 0.215], "cup_noodle": [0.110, 0.110, 0.120]},
    }
    if manifest.get("product_setup", {}).get("shape_dimensions_m") != expected_product_shapes.get(fixture):
        errors.append("product shape dimensions do not match the fixture contract")
    repository_root = Path(__file__).resolve().parents[2]
    for relative, digest in provenance.get("source_art_sha256", {}).items():
        source_path = repository_root / relative
        if not source_path.is_file():
            errors.append("missing generated source art: %s" % relative)
        elif hashlib.sha256(source_path.read_bytes()).hexdigest() != digest:
            errors.append("generated source art hash mismatch: %s" % relative)
    for key, (dx, dy, tolerance) in EXPECTED_PROJECTION.items():
        actual = [centers[key][0] - origin[0], centers[key][1] - origin[1]]
        projection[key] = {"actual_px": actual, "expected_px": [dx, dy], "tolerance_px": tolerance}
        if abs(actual[0] - dx) > tolerance or abs(actual[1] - dy) > tolerance:
            errors.append("%s projection delta outside tolerance: %s" % (key, actual))
    render_info_origin = provenance.get("origin_px", [800, 800])
    if abs(origin[0] - render_info_origin[0]) > 1 or abs(origin[1] - render_info_origin[1]) > 1:
        errors.append("calibration origin differs from render origin")

    image_count = 0
    stock_counts = {"FULL": [], "HALF": [], "EMPTY": []}
    expected_counts = manifest["product_counts_by_state"]
    for state, state_record in manifest["states"].items():
        if state not in stock_counts or set(state_record["rotations"]) != {"0", "1", "2", "3"}:
            errors.append("invalid stock state or rotation set: %s" % state)
            continue
        for rotation, record in state_record["rotations"].items():
            width, depth, height = [record["mesh_bbox"]["max"][i] - record["mesh_bbox"]["min"][i] for i in range(3)]
            expected_width, expected_depth = (manifest["dimensions_m"]["width"], manifest["dimensions_m"]["depth"])
            if int(rotation) % 2:
                expected_width, expected_depth = expected_depth, expected_width
            if width > expected_width + 0.001 or depth > expected_depth + 0.001 or abs(height - manifest["dimensions_m"]["height"]) > 0.01:
                errors.append("r%s mesh bbox outside fixture size: %.4f x %.4f x %.4f" % (rotation, width, depth, height))
            if not set(("body", "products", "glass_front", "shadow", "composite")).issubset(record["layers"]):
                errors.append("missing required layers: %s r%s" % (state, rotation))
            for layer, name in record["layers"].items():
                path = base / name
                if not path.is_file():
                    errors.append("missing layer file: %s" % path)
                    continue
                with Image.open(path) as image:
                    image_count += 1
                    if image.mode != "RGBA" or list(image.size) != record["canvas_px"]:
                        errors.append("image mode/canvas mismatch: %s" % path.name)
                    if layer == "products":
                        stock_counts[state].append(int(np.count_nonzero(np.asarray(image.getchannel("A")) > 0)))
            baseline = manifest["states"]["FULL"]["rotations"].get(rotation)
            if baseline and (baseline["canvas_px"] != record["canvas_px"] or baseline["anchor_px"] != record["anchor_px"]):
                errors.append("stock-state crop/anchor mismatch: %s r%s" % (state, rotation))
            if manifest.get("runtime_approved") is not False:
                errors.append("candidate must remain runtime_approved:false")
            if record.get("product_count") != expected_counts[state]:
                errors.append("%s should contain %d modeled products, got %s" % (state, expected_counts[state], record.get("product_count")))

    for rotation in range(4):
        full_pixels = stock_counts["FULL"][rotation]
        half_pixels = stock_counts["HALF"][rotation]
        empty_pixels = stock_counts["EMPTY"][rotation]
        if not (full_pixels > half_pixels > empty_pixels == 0):
            errors.append("products layer alpha coverage is not FULL > HALF > EMPTY at r%d: %s/%s/%s" % (rotation, full_pixels, half_pixels, empty_pixels))

    report = {
        "fixture_type_id": fixture,
        "calibration": {"status": "PASS" if not errors else "FAIL", "origin_px": origin, "projection": projection},
        "mesh_dimensions": {"status": "PASS" if not errors else "FAIL", "expected_dimensions_m": manifest["dimensions_m"], "footprint": manifest["footprint"], "per_rotation_measured": {r: manifest["states"]["FULL"]["rotations"][r]["mesh_bbox"] for r in ("0", "1", "2", "3")}},
        "rgba_layer_images_checked": image_count,
        "product_counts_by_state": expected_counts,
        "runtime_approved": False,
        "errors": errors,
    }
    if args.report:
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("FAIL\n- " + "\n- ".join(errors))
        raise SystemExit(1)
    print("PASS: iso2x calibration, 12 states/rotations, product counts %s/%s/%s, measured bbox, RGBA layer/crop consistency" % (expected_counts["FULL"], expected_counts["HALF"], expected_counts["EMPTY"]))
    if args.report:
        print("REPORT:", args.report)


if __name__ == "__main__":
    main()
