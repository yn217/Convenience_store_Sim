"""Deterministic Pillow source renderer for Issue #91 shelf_general inventory states."""
from __future__ import annotations
import hashlib, json, math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/source/textures/fixtures/inventory_states/shelf_general"
W, H = 442, 450
ANCHORS = {0:(285,303), 1:(157,303), 2:(285,303), 3:(157,303)}
PALETTE = {
    "snack": ((238,154,48),(255,210,75)),
    "instant_noodle": ((214,84,55),(250,139,79)),
    "bread": ((190,119,61),(235,177,95)),
}

def iso(x, y, z, rot):
    # 45° footprint and 30° vertical projection; rotate world coordinates per view.
    for _ in range(rot): x, y = -y, x
    return (285 + (x-y)*128, 303 + (x+y)*64 - z*104)

def poly(draw, pts, fill, outline=None, width=1):
    draw.polygon(pts, fill=fill)
    if outline: draw.line(pts+[pts[0]], fill=outline, width=width, joint="curve")

def render(rot, state, layer):
    im = Image.new("RGBA", (W,H), (0,0,0,0)); d = ImageDraw.Draw(im)
    # shadow layer
    if layer == "shadow":
        p=[iso(-.48,-.96,0,rot),iso(.48,-.96,0,rot),iso(.48,.96,0,rot),iso(-.48,.96,0,rot)]
        poly(d,p,(28,35,42,72)); return im
    if layer == "products":
        counts={"FULL":8,"HALF":5,"EMPTY":0}[state]
        for row in range(4):
            for col in range(counts):
                # Deliberately deterministic but nonuniform HALF spacing and category coding.
                t = (row*11+col*7+rot*3) % 3
                x = -0.40 + col*(0.80/max(1,counts-1)) if counts>1 else 0
                y = -0.78 + row*0.52
                z = 0.32 + (t%2)*0.025
                cx,cy=iso(x,y,z,rot); bw,bh=15,27
                c1,c2=PALETTE[("snack","instant_noodle","bread")[t]]
                d.rounded_rectangle((cx-bw//2,cy-bh,cx+bw//2,cy),radius=3,fill=c1+(255,),outline=(91,57,35,255),width=1)
                d.rectangle((cx-bw//2+2,cy-bh+5,cx+bw//2-2,cy-bh+10),fill=c2+(255,))
                d.line((cx-4,cy-6,cx+4,cy-6),fill=(255,245,205,255),width=1)
        return im
    # body: cabinet, shelves and side posts; each rotation is projected directly.
    for z in (0.18,0.58,0.98,1.38):
        poly(d,[iso(-.44,-.90,z,rot),iso(.44,-.90,z,rot),iso(.44,.90,z,rot),iso(-.44,.90,z,rot)],(148,104,65,255), (79,59,43,255))
    for x in (-.46,.46):
        p=[iso(x,-.92,0,rot),iso(x,-.92,1.5,rot),iso(x,.92,1.5,rot),iso(x,.92,0,rot)]
        poly(d,p,(104,76,54,255),(57,45,36,255))
    # top cap and front lip emphasizes E-facing display edge for every independent view.
    poly(d,[iso(-.48,-.96,1.5,rot),iso(.48,-.96,1.5,rot),iso(.48,.96,1.5,rot),iso(-.48,.96,1.5,rot)],(184,139,86,255),(71,52,37,255))
    return im

def composite(*layers):
    out=Image.new("RGBA",(W,H),(0,0,0,0))
    for layer in layers: out=Image.alpha_composite(out,layer)
    return out

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    files=[]
    for state in ("FULL","HALF","EMPTY"):
        for rot in range(4):
            names={k:f"shelf_general_{state.lower()}_r{rot}_{k}.png" for k in ("body","products","shadow")}
            for k,n in names.items():
                p=OUT/n; render(rot,state,k).save(p); files.append(p)
            comp=composite(render(rot,state,"shadow"),render(rot,state,"body"),render(rot,state,"products"))
            p=OUT/f"shelf_general_{state.lower()}_r{rot}_composite.png"; comp.save(p); files.append(p)
    manifests={}
    for state in ("FULL","HALF","EMPTY"):
        rots={}
        for rot in range(4):
            rots[str(rot)]={"canvas_px":[W,H],"anchor_px":list(ANCHORS[rot]),"visual_state":state,"rotation":rot,
              "layers":{"body":f"shelf_general_{state.lower()}_r{rot}_body.png","products":f"shelf_general_{state.lower()}_r{rot}_products.png","shadow":f"shelf_general_{state.lower()}_r{rot}_shadow.png","composite":f"shelf_general_{state.lower()}_r{rot}_composite.png"},
              "selection_polygon_px":[[285,239],[413,303],[285,367],[157,303]],"sorting_anchor_px":list(ANCHORS[rot]),
              "slot_anchors_px":{f"row{r}":[285,249-r*50] for r in range(4)}}
        manifests[state]={"manifest_version":1,"fixture_type_id":"shelf_general","visual_id":"shelf_general_inventory_"+state.lower(),"projection_id":"iso2x_v1","projection":{"angle_xy_deg":45,"vertical_angle_deg":30},"source_px_per_tile":[256,128],"dimensions_m":{"width":0.92,"depth":1.92,"height":1.50},"footprint":{"w":1,"h":2},"front":"E","visual_state":state,"rotations":rots}
        (OUT/f"manifest_{state.lower()}.json").write_text(json.dumps(manifests[state],ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    files += list(OUT.glob("manifest_*.json"))
    provenance={"issue":"#91","fixture_type_id":"shelf_general","generator":"tools/assets/generate_shelf_general_inventory.py","deterministic":True,"renderer":"Pillow","runtime_approved":False,"blender_verified":False,"blender_note":"Blender未検証。Pillow形状再現を使用。","source_px_per_tile":[256,128],"projection":"iso2x_v1 / 45° / 30°","states":["FULL","HALF","EMPTY"],"rotations":[0,1,2,3],"sha256":{p.name:sha(p) for p in sorted(files)}}
    (OUT/"PROVENANCE.json").write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

if __name__ == "__main__": main()
