"""Focused packaging and iso2x calibration check for an Issue #91 candidate."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

EXPECTED = {"marker_x": (128.0, 64.0, 1.0), "marker_y": (-128.0, 64.0, 1.0), "marker_z": (0.0, -156.76734354, 2.0)}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("candidate_dir", type=Path)
    p.add_argument("--report", type=Path)
    a = p.parse_args()
    base = a.candidate_dir
    prov = json.loads((base / "provenance.json").read_text(encoding="utf-8"))
    manifest = json.loads((base / "manifest.json").read_text(encoding="utf-8"))
    calibration = np.asarray(Image.open(base / prov["calibration"]["file"]).convert("RGBA"), dtype=np.float64)
    r, g, b, alpha = (calibration[..., i] for i in range(4))
    masks = {
        "marker_o": (r > 200) & (g > 200) & (b > 200) & (alpha > 200),
        "marker_x": (r > 200) & (g < 60) & (b < 60) & (alpha > 200),
        "marker_y": (g > 200) & (r < 60) & (b < 60) & (alpha > 200),
        "marker_z": (b > 200) & (r < 60) & (g < 60) & (alpha > 200),
    }
    centers = {}
    for key, mask in masks.items():
        ys, xs = np.nonzero(mask)
        if not len(xs):
            raise SystemExit(f"FAIL: no marker pixels for {key}")
        weights = alpha[ys, xs]
        centers[key] = [float(((xs + .5) * weights).sum() / weights.sum()), float(((ys + .5) * weights).sum() / weights.sum())]
    origin = centers["marker_o"]
    measurements = {}
    errors = []
    for key, (dx, dy, tol) in EXPECTED.items():
        observed = [centers[key][0] - origin[0], centers[key][1] - origin[1]]
        measurements[key] = {"observed_px": observed, "expected_px": [dx, dy], "tolerance_px": tol}
        if abs(observed[0] - dx) > tol or abs(observed[1] - dy) > tol:
            errors.append(f"{key} projection mismatch: {observed}")
    if abs(origin[0] - prov["origin_px"][0]) > 1 or abs(origin[1] - prov["origin_px"][1]) > 1:
        errors.append(f"origin mismatch: {origin}")
    image_count = 0
    for state in ("FULL", "HALF", "EMPTY"):
        rotations = manifest["states"].get(state, {}).get("rotations", {})
        if set(rotations) != {"0", "1", "2", "3"}:
            errors.append(f"{state} lacks exactly four rotations")
        for rotation, record in rotations.items():
            canvas = tuple(record["canvas_px"])
            anchor = record["anchor_px"]
            for layer in ("body", "products", "shadow", "composite"):
                path = base / record["layers"][layer]
                with Image.open(path) as im:
                    image_count += 1
                    if im.mode != "RGBA" or im.size != canvas:
                        errors.append(f"{path.name}: expected RGBA {canvas}, got {im.mode} {im.size}")
            baseline = manifest["states"]["FULL"]["rotations"].get(rotation, {})
            if tuple(baseline.get("canvas_px", ())) != canvas or baseline.get("anchor_px") != anchor:
                errors.append(f"{state} r{rotation}: canvas/anchor differs from FULL")
    report = {
        "fixture_type_id": prov["fixture_type_id"],
        "calibration": {"status": "PASS" if not errors else "FAIL", "origin_px": origin, "markers": measurements},
        "packaging_consistency": {"image_layers_checked": image_count, "status": "PASS" if not errors else "FAIL"},
        "runtime_approved": False,
        "errors": errors,
    }
    if a.report:
        a.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if errors:
        print("FAIL", *errors, sep="\n- ")
        raise SystemExit(1)
    print(f"PASS: measured iso2x calibration and {image_count} RGBA layer/composite files; runtime remains unapproved")
    if a.report:
        print(f"REPORT: {a.report}")


if __name__ == "__main__":
    main()
