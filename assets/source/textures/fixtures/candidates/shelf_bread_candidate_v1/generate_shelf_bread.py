from __future__ import annotations
import hashlib, json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent
PROJECTION = "iso2x_v1"
ZPX = 156.76734354
PADDING = 8
RENDER_SIZE = (640, 640)
ORIGIN = (320, 480)

def proj(x, y, z):
    return (ORIGIN[0] + 128 * (x - y), ORIGIN[1] + 64 * (x + y) - ZPX * z)

def polygon(draw, pts, fill, outline=None, width=1):
    draw.polygon([(round(x), round(y)) for x, y in pts], fill=fill)
    if outline:
        draw.line([(round(x), round(y)) for x, y in pts + [pts[0]]], fill=outline, width=width, joint="curve")

def box_faces(draw, x0, x1, y0, y1, z0, z1, colors):
    top = [proj(x0,y0,z1), proj(x1,y0,z1), proj(x1,y1,z1), proj(x0,y1,z1)]
    east = [proj(x1,y0,z0), proj(x1,y1,z0), proj(x1,y1,z1), proj(x1,y0,z1)]
    south = [proj(x0,y1,z0), proj(x1,y1,z0), proj(x1,y1,z1), proj(x0,y1,z1)]
    polygon(draw, south, colors[0], "#48362c", 2)
    polygon(draw, east, colors[1], "#48362c", 2)
    polygon(draw, top, colors[2], "#6d513d", 2)

def render(rotation):
    body = Image.new("RGBA", RENDER_SIZE, (0,0,0,0))
    shadow = Image.new("RGBA", RENDER_SIZE, (0,0,0,0))
    db, ds = ImageDraw.Draw(body), ImageDraw.Draw(shadow)
    polygon(ds, [proj(-0.46,-0.46,0), proj(0.46,-0.46,0), proj(0.46,1.46,0), proj(-0.46,1.46,0)], (26,18,12,76))
    box_faces(db, -0.46, 0.46, -0.46, 1.46, 0.04, 1.50, ("#a96f3f", "#c18a53", "#e3b878"))
    for z in (0.52, 0.91, 1.30):
        box_faces(db, -0.43, 0.43, 1.30, 1.43, z, z+0.055, ("#6e452b", "#85532f", "#bd7a3d"))
        for i in range(5):
            cx = -0.34 + i * 0.17
            box_faces(db, cx-0.055, cx+0.055, 1.30, 1.40, z+0.055, z+0.22, ("#8c4d2a", "#c56b35", "#f0b25c"))
    box_faces(db, -0.43, 0.43, 1.29, 1.44, 1.34, 1.50, ("#8e4e2e", "#a75b32", "#d78441"))
    if rotation:
        body = body.rotate(-90*rotation, center=ORIGIN, resample=Image.Resampling.BICUBIC, expand=False)
        shadow = shadow.rotate(-90*rotation, center=ORIGIN, resample=Image.Resampling.BICUBIC, expand=False)
    return body, shadow

def crop_pair(body, shadow):
    alpha = ImageChops.lighter(body.getchannel("A"), shadow.getchannel("A"))
    bbox = alpha.getbbox()
    left, top = max(0,bbox[0]-PADDING), max(0,bbox[1]-PADDING)
    right, bottom = min(RENDER_SIZE[0],bbox[2]+PADDING), min(RENDER_SIZE[1],bbox[3]+PADDING)
    return body.crop((left,top,right,bottom)), shadow.crop((left,top,right,bottom)), (left,top,right,bottom)

def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    rotations = []
    for r in range(4):
        body, shadow, crop = crop_pair(*render(r))
        bp, sp = ROOT/f"shelf_bread_r{r}_body.png", ROOT/f"shelf_bread_r{r}_shadow.png"
        body.save(bp, format="PNG", optimize=False, compress_level=9)
        shadow.save(sp, format="PNG", optimize=False, compress_level=9)
        anchor = [round(ORIGIN[0]-crop[0],2), round(ORIGIN[1]-crop[1],2)]
        canvas = list(body.size)
        footprint = [[round(proj(-.5,-.5,0)[0]-crop[0]),round(proj(-.5,-.5,0)[1]-crop[1])],[round(proj(.5,-.5,0)[0]-crop[0]),round(proj(.5,-.5,0)[1]-crop[1])],[round(proj(.5,1.5,0)[0]-crop[0]),round(proj(.5,1.5,0)[1]-crop[1])],[round(proj(-.5,1.5,0)[0]-crop[0]),round(proj(-.5,1.5,0)[1]-crop[1])]]
        rotations.append({"rotation":r,"body":bp.name,"shadow":sp.name,"canvas_px":canvas,"anchor_px":anchor,"sorting_anchor_px":anchor,"selection_polygon_px":footprint,"footprint_polygon_px":footprint,"layers":{"body":bp.name,"shadow":sp.name},"sha256":{"body":sha256(bp),"shadow":sha256(sp)}})
    manifest = {"manifest_version":1,"asset_id":"shelf_bread_candidate_v1","type_id":"shelf_bread","status":"review-only","runtime_approved":False,"generation":{"method":"deterministic_pillow","script":"generate_shelf_bread.py","seed":None},"projection_id":PROJECTION,"source_px_per_tile":[256,128],"world_units_per_tile":1.0,"footprint":[1,2],"dimensions_m":{"width":0.92,"depth":1.92,"height":1.50},"access_edge":"E","origin_pivot":[0,0,0],"rotations":rotations,"notes":"RGBA review-only fixture candidate; no Godot/runtime files modified."}
    (ROOT/"shelf_bread_candidate_v1.visual.manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    provenance = {"asset_id":"shelf_bread_candidate_v1","status":"review-only","runtime_approved":False,"source":"original deterministic Pillow geometry; no third-party raster assets","generator":"generate_shelf_bread.py","projection_id":PROJECTION,"camera":{"azimuth_deg":45,"elevation_deg":30,"scale":"iso2x_v1"},"physical_contract":{"footprint":[1,2],"body_max_m":[0.92,1.92],"height_m":1.50,"access_edge":"E"},"files":[{"rotation":x["rotation"],"body":x["body"],"body_sha256":x["sha256"]["body"],"shadow":x["shadow"],"shadow_sha256":x["sha256"]["shadow"]} for x in rotations]}
    (ROOT/"shelf_bread_candidate_v1.provenance.json").write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

if __name__ == "__main__": main()
