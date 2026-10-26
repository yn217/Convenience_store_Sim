"""Uniformly package the geometry-guided imagegen planter; measure projected edges."""
import json
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
ID = "flower_planter_painted_v1"
SOURCE = ROOT / "assets/source/exterior" / ID / "source.png"
OUT = ROOT / "assets/generated/props" / ID


def edge_fit(alpha, start, stop):
    points = []
    for x in range(start, stop):
        ys = np.where(alpha[:, x] > 180)[0]
        if len(ys):
            points.append((x, int(ys[-1])))
    return float(np.polyfit(*np.array(points).T, 1)[0])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    alpha = np.asarray(source)[:, :, 3]
    slopes = [edge_fit(alpha, 220, 680), edge_fit(alpha, 750, 900)]
    canvas = Image.new("RGBA", (512, 512))
    canvas.alpha_composite(source.resize((502, 502), Image.Resampling.LANCZOS), (5, 5))
    canvas.save(OUT / f"{ID}_0_body.png")
    rot = {"canvas_px": [512, 512], "anchor_px": [226, 293],
           "layers": {"body": f"{ID}_0_body.png"},
           "sorting_anchor_px": [226, 293], "slot_anchors_px": {},
           "selection_polygon_px": [[165,221], [370,323], [287,365], [82,263]]}
    manifest = {"manifest_version": 1, "visual_id": ID, "fixture_type_id": ID,
                "projection_id": "iso2x_v1", "world_units_per_tile": 1,
                "source_px_per_tile_diamond": [256,128], "footprint": {"w":2,"h":1},
                "dimensions_m": {"width":1.6,"depth":0.65,"height":0.65},
                "rotations": {"0":rot,"2":rot}}
    (OUT / f"{ID}.visual.json").write_text(json.dumps(manifest, indent=2) + "\n")
    report = {"source_bottom_edge_slopes":slopes,"ideal_slopes":[0.5,-0.5],
              "max_absolute_slope_error":max(abs(slopes[0]-.5),abs(slopes[1]+.5)),
              "status":"candidate_pending_runtime_QA", "canvas_px":[512,512],
              "anchor_px":[226,293],"alpha_extrema":canvas.getextrema()[3]}
    assert canvas.getextrema()[3] == (0,255)
    assert report["max_absolute_slope_error"] < .03
    assert canvas.getpixel((226,293))[3] > 180
    (OUT / "QA.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
