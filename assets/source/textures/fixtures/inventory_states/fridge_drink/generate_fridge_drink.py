"""Deterministic Pillow generator for fridge_drink inventory-state sprites.

The output is review-only until runtime integration and Blender/camera calibration
are verified. It deliberately writes only inside this fixture directory.
"""
from hashlib import sha256
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SIZE = (512, 512)
ANCHOR = (256, 438)
XDIAMOND, YDIAMOND, ZPX = 128.0, 64.0, 156.76734354
STATES = {"FULL": 1.0, "HALF": 0.56, "EMPTY": 0.0}

def iso(x, y, z=0.0):
    return (ANCHOR[0] + XDIAMOND * (x-y), ANCHOR[1] + YDIAMOND * (x+y) - ZPX*z)

def render(state, rotation):
    layers = {n: Image.new("RGBA", SIZE, (0, 0, 0, 0)) for n in ("body", "products", "glass_front", "shadow")}
    sd = ImageDraw.Draw(layers["shadow"])
    footprint = [(0, 0, 0), (0, 2, 0), (1, 2, 0), (1, 0, 0)]
    sd.polygon([iso(*p) for p in footprint], fill=(8, 12, 18, 86))
    def tr(x, y, z):
        return [(x, y, z), (2-y, x, z), (1-x, 2-y, z), (y, 1-x, z)][rotation]
    def P(x, y, z=0): return iso(*tr(x, y, z))
    def pg(draw, pts, fill, outline=None, width=1):
        draw.polygon([P(*p) for p in pts], fill=fill, outline=outline, width=width)
    bd = ImageDraw.Draw(layers["body"])
    # 0.92 x 1.92 x 2.00m cabinet, local front/access edge E at x=1.
    pg(bd, [(0.04,0.04,0),(0.96,0.04,0),(0.96,1.96,0),(0.04,1.96,0)], (61,72,82,255), (25,31,38,255), 2)
    pg(bd, [(0.04,0.04,2.0),(0.96,0.04,2.0),(0.96,1.96,2.0),(0.04,1.96,2.0)], (105,118,128,255), (33,40,48,255), 2)
    pg(bd, [(0.04,0.04,0),(0.04,1.96,0),(0.04,1.96,2.0),(0.04,0.04,2.0)], (40,48,57,255), (22,27,33,255), 2)
    # Bottom plinth and two vertical end frames.
    pg(bd, [(0.04,0.04,0.06),(0.96,0.04,0.06),(0.96,1.96,0.06),(0.04,1.96,0.06)], (30,38,45,255))
    for y in (0.06, 1.84):
        pg(bd, [(0.78,y,0.08),(0.96,y,0.08),(0.96,y+0.12,0.08),(0.78,y+0.12,0.08)], (24,31,38,255))
        pg(bd, [(0.78,y,0.08),(0.96,y,0.08),(0.96,y,1.94),(0.78,y,1.94)], (50,61,70,255), (24,30,36,255), 1)
    # Shelves visible through front glass.
    for z in (0.48, 0.92, 1.36, 1.78):
        pg(bd, [(0.12,0.08,z),(0.86,0.08,z),(0.86,1.92,z),(0.12,1.92,z)], (112,123,128,230), (42,50,56,255), 1)
    pd = ImageDraw.Draw(layers["products"])
    counts_by_state = {"FULL": (6, 5, 5, 4), "HALF": (4, 3, 2, 1), "EMPTY": (0, 0, 0, 0)}
    for row, z in enumerate((0.52, 0.96, 1.40, 1.82)):
        # Sparse deterministic occupancy: HALF is visibly depleted, never alpha-faded.
        count = counts_by_state[state][row]
        for i in range(count):
            y = 0.18 + i * (1.54 / max(1, count-1)) if count > 1 else 0.92
            color = [(44,145,205,255),(235,171,43,255),(220,73,59,255),(75,179,105,255)][(i+row) % 4]
            pg(pd, [(0.54,y-0.10,z),(0.78,y-0.10,z),(0.78,y+0.10,z),(0.54,y+0.10,z)], color, (28,44,54,255), 1)
            pg(pd, [(0.54,y-0.10,z),(0.54,y+0.10,z),(0.54,y+0.10,z+0.28),(0.54,y-0.10,z+0.28)], tuple(max(0,c-35) for c in color[:3])+(255,), (22,35,43,255), 1)
    gd = ImageDraw.Draw(layers["glass_front"])
    # Glass is always present and opaque enough to retain its visual identity.
    pg(gd, [(0.80,0.08,0.10),(0.94,0.08,0.10),(0.94,1.92,0.10),(0.80,1.92,0.10)], (126,205,224,54), (184,235,244,180), 2)
    pg(gd, [(0.83,0.12,0.18),(0.87,0.12,0.18),(0.87,1.88,0.18),(0.83,1.88,0.18)], (230,250,255,72))
    pg(gd, [(0.94,0.08,0.10),(0.98,0.08,0.10),(0.98,1.92,0.10),(0.94,1.92,0.10)], (30,49,60,245), (12,22,28,255), 1)
    # Composite order is explicit: shadow -> body -> products -> glass_front.
    composite = Image.new("RGBA", SIZE, (0,0,0,0))
    for name in ("shadow", "body", "products", "glass_front"):
        composite.alpha_composite(layers[name])
    return layers, composite

def main():
    rotations = {}
    for state in STATES:
        for r in range(4):
            layers, composite = render(state, r)
            stem = f"fridge_drink_{state.lower()}_r{r}"
            layer_names = {}
            for name, image in layers.items():
                fn = f"{stem}_{name}.png"; image.save(ROOT / fn, optimize=False, compress_level=9); layer_names[name] = fn
            out = f"{stem}.png"; composite.save(ROOT / out, optimize=False, compress_level=9)
            rotations[f"{state.lower()}_r{r}"] = {"state": state, "rotation": r, "canvas_px": list(SIZE), "anchor_px": list(ANCHOR), "layers": layer_names, "composite": out, "composition_order": ["shadow", "body", "products", "glass_front"]}
    manifest = {"manifest_version": 1, "visual_id": "fridge_drink_inventory_states_v1", "fixture_type_id": "fridge_drink", "projection_id": "iso2x_v1", "source_px_per_tile": [256,128], "dimensions_m": {"width":0.92,"depth":1.92,"height":2.00}, "footprint": {"w":1,"h":2}, "front": "E", "canvas_px": list(SIZE), "anchor_px": list(ANCHOR), "states": ["FULL","HALF","EMPTY"], "rotations": [0,1,2,3], "rotations_states": rotations}
    (ROOT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    files = sorted(p for p in ROOT.glob("*.png"))
    provenance = {"runtime_approved": False, "generator": "Pillow deterministic fallback", "generator_script": "generate_fridge_drink.py", "blender_used": False, "source_px_per_tile": [256,128], "dimensions_m": [0.92,1.92,2.00], "unverified_points": ["Blender camera calibration and projection tolerance are not verified.", "Godot import/runtime integration is intentionally not performed.", "Visual acceptance of product readability and glass occlusion remains pending."], "sha256": {p.name: sha256(p.read_bytes()).hexdigest() for p in files}, "files": [p.name for p in files]}
    (ROOT / "provenance.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ROOT / "SHA256SUMS.txt").write_text("".join(f"{sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in files), encoding="utf-8")

if __name__ == "__main__": main()
