import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
W, H = 512, 512
ANCHOR = (272, 382)
SLOT_X = [168, 198, 228, 258, 288, 318, 348]
ROWS = [150, 205, 260]
STATES = {"FULL": 0.96, "HALF": 0.52, "EMPTY": 0.0}

def iso(x, y, z):
    return (ANCHOR[0] + 128 * (x - y), ANCHOR[1] + 64 * (x + y) - 135 * z)

def draw_cylinder(d, cx, cy, radius=13, height=26, color=(224, 164, 62, 255), seed=0):
    # Readable cup/noodle silhouette: ellipse lid + tapered cylindrical body.
    d.ellipse((cx-radius, cy-height//2-radius//3, cx+radius, cy-height//2+radius//3), fill=(250, 207, 91, 255), outline=(93, 55, 30, 255), width=2)
    d.polygon([(cx-radius, cy-height//2), (cx+radius, cy-height//2), (cx+radius-3, cy+height//2), (cx-radius+3, cy+height//2)], fill=color)
    d.line((cx-radius, cy-height//2, cx-radius+3, cy+height//2), fill=(93,55,30,255), width=2)
    d.line((cx+radius, cy-height//2, cx+radius-3, cy+height//2), fill=(93,55,30,255), width=2)
    d.ellipse((cx-radius+3, cy+height//2-4, cx+radius-3, cy+height//2+4), fill=(168, 94, 37, 255), outline=(93,55,30,255), width=1)
    d.line((cx-radius+5, cy-height//2, cx+radius-5, cy-height//2), fill=(255, 232, 148, 255), width=2)
    d.line((cx-5, cy-height//2+3, cx+5, cy-height//2+3), fill=(130, 74, 36, 255), width=1)

def fixture_layer(rotation):
    im = Image.new("RGBA", (W, H), (0,0,0,0)); d = ImageDraw.Draw(im)
    # rotated footprint, shelf bays, side posts, and top cap
    long = rotation in (0,2)
    a,b = (-.46,.46) if long else (-.46,1.46)
    y0,y1 = (-.46,1.46) if long else (-.46,.46)
    for z in (0.08, .52, .96, 1.40, 1.66):
        q = [iso(a,y0,z), iso(b,y0,z), iso(b,y1,z), iso(a,y1,z)]
        d.polygon(q, fill=(112,121,124,255), outline=(37,43,47,255))
        d.line([q[0],q[1]], fill=(204,168,101,255), width=6)
    for x,y in ((a,y0),(b,y0),(b,y1),(a,y1)):
        d.line([iso(x,y,.08), iso(x,y,1.70)], fill=(43,49,53,255), width=7)
    return im

def product_layer(state, rotation):
    im = Image.new("RGBA", (W, H), (0,0,0,0)); d = ImageDraw.Draw(im)
    count = {"FULL": 7, "HALF": 4, "EMPTY": 0}[state]
    for row, z in enumerate((1.42, .98, .54)):
        # HALF is intentionally sparse, with varied gaps and no alpha reduction.
        indices = list(range(count)) if state != "HALF" else ([0, 2, 5, 6] if row != 1 else [1, 4, 6])
        for i in indices:
            cx, cy = SLOT_X[i], ROWS[row]
            if rotation in (1,3): cx = W - cx
            draw_cylinder(d, cx, cy, color=((211 + row*8, 105 + i*9, 45 + row*6, 255)), seed=i+row)
    return im

def shadow_layer(rotation):
    im = Image.new("RGBA", (W, H), (0,0,0,0)); d = ImageDraw.Draw(im)
    if rotation in (0,2): q=[iso(-.46,-.46,0),iso(.46,-.46,0),iso(.46,1.46,0),iso(-.46,1.46,0)]
    else: q=[iso(-.46,-.46,0),iso(1.46,-.46,0),iso(1.46,.46,0),iso(-.46,.46,0)]
    d.polygon(q, fill=(25,20,18,78))
    return im

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"manifest_version": 1, "visual_id":"shelf_noodle_inventory_v1", "fixture_type_id":"shelf_noodle", "projection_id":"iso2x_v1", "projection":{"azimuth_deg":45,"elevation_deg":30,"source_px_per_tile":[256,128]}, "dimensions_m":{"width":0.92,"depth":1.92,"height":1.70}, "footprint":[1,2], "front":"E", "runtime_approved":False, "rotations":{}}
    for state in STATES:
        for rotation in range(4):
            body = fixture_layer(rotation); products = product_layer(state, rotation); shadow = shadow_layer(rotation)
            composite = Image.alpha_composite(Image.alpha_composite(shadow, body), products)
            stem = f"shelf_noodle_{state.lower()}_r{rotation}"
            body.save(OUT/(stem+"_body.png"), compress_level=9); products.save(OUT/(stem+"_products.png"), compress_level=9); shadow.save(OUT/(stem+"_shadow.png"), compress_level=9); composite.save(OUT/(stem+".png"), compress_level=9)
            anchor = [W-ANCHOR[0], ANCHOR[1]] if rotation in (1,3) else list(ANCHOR)
            manifest["rotations"].setdefault(str(rotation), {"canvas_px":[W,H],"anchor_px":anchor,"states":{}})["states"][state] = {"composite":stem+".png","layers":{"body":stem+"_body.png","products":stem+"_products.png","shadow":stem+"_shadow.png"},"canvas_px":[W,H],"anchor_px":anchor,"product_alpha_policy":"opaque_per_item; HALF uses fewer items, never 50% alpha"}
    (OUT/"manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    prov = {"issue":"#91","generator":"Pillow deterministic fallback","blender_available":False,"runtime_approved":False,"regeneration":"python generate_shelf_noodle.py","unverified_points":["Blender render/projection calibration not verified.","Godot runtime integration intentionally not run.","Human visual review of final silhouette and anchors remains pending."],"composition":"shadow -> body -> products; each is saved separately and composite is explicit."}
    (OUT/"provenance.json").write_text(json.dumps(prov, indent=2)+"\n", encoding="utf-8")
    # Include metadata and script hashes after the image pass.
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.is_file() and p.name != "SHA256SUMS.json"}
    (OUT/"SHA256SUMS.json").write_text(json.dumps(hashes, indent=2)+"\n", encoding="utf-8")

if __name__ == "__main__": main()
