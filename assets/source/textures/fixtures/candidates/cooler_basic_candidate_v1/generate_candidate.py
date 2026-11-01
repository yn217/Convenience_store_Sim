"""Deterministic review-only cooler candidate generator.

Fallback for hosts without Blender. It uses the repository's iso2x_v1 projection
numbers and Pillow only; output is deliberately not wired into Godot runtime.
"""
from __future__ import annotations
import hashlib, json, math, platform, sys
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
W, H, Z = 0.92, 1.92, 2.00
CANVAS = (512, 512)
ORIGIN = (256.0, 380.0)
ZPX = 156.76734354

def project(x, y, z=0.0):
    return (ORIGIN[0] + 128*(x-y), ORIGIN[1] + 64*(x+y) - ZPX*z)

def rot(x, y, r):
    return [(x,y), (-y,x), (-x,-y), (y,-x)][r % 4]

def points3(points, r, z=0.0):
    return [project(*rot(x,y,r), z) for x,y in points]

def poly(draw, pts, fill, outline=None, width=1):
    draw.polygon([(round(x),round(y)) for x,y in pts], fill=fill)
    if outline: draw.line([(round(x),round(y)) for x,y in pts+[pts[0]]], fill=outline, width=width, joint="curve")

def render(r):
    body = Image.new("RGBA", CANVAS, (0,0,0,0)); d = ImageDraw.Draw(body)
    shadow = Image.new("RGBA", CANVAS, (0,0,0,0)); sd = ImageDraw.Draw(shadow)
    footprint = [(-.46,-.96),(.46,-.96),(.46,.96),(-.46,.96)]
    poly(sd, points3(footprint, r, 0.006), (18,24,30,92))
    # base and cabinet, back first
    poly(d, points3(footprint, r, .08), (38,48,58,255), (18,24,30,255), 2)
    top = [(-.46,-.96),(.46,-.96),(.46,.96),(-.46,.96)]
    poly(d, points3(top, r, 2.0), (104,120,130,255), (26,34,40,255), 2)
    for z in (.10, .46, .96, 1.46, 1.94):
        poly(d, points3([(-.46,-.96),(.46,-.96),(.46,.96),(-.46,.96)], r, z), (48,62,70,255), (20,28,34,255), 1)
    # front-facing glass plane is the local +X edge, with four doors
    for y0,y1 in [(-.92,-.48),(-.46,-.02),(.02,.46),(.48,.92)]:
        poly(d, points3([(.45,y0),(.45,y1),(.45,y1)], r, 0.18), (56,82,92,120), (178,221,230,220), 2)
        poly(d, points3([(.455,y0),(.455,y1),(.455,y1)], r, 1.88), (80,180,198,45), (178,221,230,220), 1)
    # upright rails and shelf highlights
    for y in (-.94,-.47,0,.47,.94):
        a=project(*rot(.46,y,r),.1); b=project(*rot(.46,y,r),1.94)
        d.line((round(a[0]),round(a[1]),round(b[0]),round(b[1])), fill=(205,225,230,230), width=3)
    for z in (.46,.96,1.46):
        a=project(*rot(.47,-.91,r),z); b=project(*rot(.47,.91,r),z)
        d.line((round(a[0]),round(a[1]),round(b[0]),round(b[1])), fill=(224,236,238,190), width=3)
    # generic bottle blocks: no brands or external textures
    for z in (.58,1.08,1.58):
        for y in (-.72,-.48,-.24,0,.24,.48,.72):
            x=.36; p=project(*rot(x,y,r),z)
            d.rounded_rectangle((round(p[0]-5),round(p[1]-16),round(p[0]+5),round(p[1]+2)), radius=2, fill=(83,163,195,220), outline=(218,241,244,230), width=1)
    return body, shadow

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files=[]; directions=[]
    for r in range(4):
        body, shadow = render(r)
        for layer, image in (("body",body),("shadow",shadow)):
            name=f"{layer}_{r*90:03d}.png"; image.save(OUT/name, "PNG", optimize=False, compress_level=9); files.append(name)
        # conservative selection polygon from footprint corners and top silhouette
        selection = [[round(x),round(y)] for x,y in points3([(-.46,-.96),(.46,-.96),(.46,.96),(-.46,.96)], r, 0.0)]
        directions.append({"rotation_deg":r*90,"body_png":f"body_{r*90:03d}.png","shadow_png":f"shadow_{r*90:03d}.png","anchor_px":[256,380],"selection_polygon_px":selection,"canvas_px":list(CANVAS)})
    manifest={"manifest_version":1,"asset_id":"cooler_basic_candidate_v1","status":"review-only","projection_id":"iso2x_v1","dimensions_m":{"width":W,"depth":H,"height":Z},"footprint_tiles":[1,2],"canvas_px":list(CANVAS),"anchor_px":[256,380],"selection_polygon_px":"per-direction in directions[]","directions":directions,"runtime_approved":False,"source_type":"deterministic_pillow_fallback"}
    (OUT/"visual_manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    sha={p:hashlib.sha256((OUT/p).read_bytes()).hexdigest() for p in files+['visual_manifest.json']}
    prov={"asset_id":"cooler_basic_candidate_v1","generator":"generate_candidate.py","generator_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"sha256":sha,"runtime_approved":False,"blender":{"available":False,"attempted":True},"unverified_points":["Blender mesh bbox and camera calibration not executed","RGBA alpha/anchor semantics are procedural fallback only","visual quality, glass ordering, and Godot placement require human review","not registered in Godot scenes or runtime asset catalogs"],"environment":{"python":sys.version,"platform":platform.platform()}}
    (OUT/"provenance.json").write_text(json.dumps(prov,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
if __name__ == "__main__": main()
