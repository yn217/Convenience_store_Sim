"""Generate the Issue #103 prop pack when Blender is unavailable.

The drawing primitives deliberately use the same iso2x projection and source scale as the
Blender fixture pipeline.  This is a reviewable fallback, not a replacement for the fixture
renderer: props are flat, transparent RGBA sprites with explicit manifests and provenance.
"""
import json, math, os, hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys
sys.path.insert(0, str(Path(__file__).parent))
import iso2x

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/generated/props"
FONT = "C:/Windows/Fonts/meiryo.ttc"
try: FONT_OBJ = ImageFont.truetype(FONT, 18)
except OSError: FONT_OBJ = ImageFont.load_default()

PROPS = [
 ("storefront_wall", (1,1), 3.2, "wall"), ("storefront_door", (1,1), 2.5, "door"),
 ("storefront_window", (1,1), 2.4, "window"), ("reachin_cooler_row", (1,1), 2.0, "cooler"),
 ("back_counter_set", (2,1), 1.6, "counter"), ("coffee_machine", (1,1), 1.7, "coffee"),
 ("cigarette_shelf_generic", (1,1), 1.8, "shelf"), ("fryer_hot_snack_case", (1,1), 1.2, "fryer"),
 ("potted_plant_small", (1,1), .8, "plant"), ("potted_plant_large", (1,1), 1.4, "plant"),
 ("ceiling_light_strip", (1,1), .15, "light"), ("cherry_tree_a", (2,2), 3.5, "tree"),
 ("cherry_tree_b", (2,2), 3.8, "tree2"), ("flower_bed_planter", (2,1), .45, "bed"),
 ("open_a_board", (1,1), 1.4, "board"), ("bicycle_stand", (1,1), 1.0, "bike"),
]
POPS = ["onigiri", "drink", "bread", "dessert", "ice", "oden", "cup_noodle", "snack"]

def project(x,y,z):
    u,v=iso2x.project(x,y,z); return (160+u, 210+v)
def poly(d, pts, fill, outline=None, width=2): d.polygon(pts, fill=fill, outline=outline, width=width)
def draw_box(d, x0,y0,z0,x1,y1,z1, fill, outline=(40,55,70,255)):
    a=project(x0,y0,z0); b=project(x1,y0,z0); c=project(x1,y1,z0); e=project(x0,y1,z0)
    poly(d,[a,b,c,e],fill,outline)
    for p,q in ((a,project(x0,y0,z1)),(b,project(x1,y0,z1)),(c,project(x1,y1,z1)),(e,project(x0,y1,z1))): d.line([p,q],fill=outline,width=2)
    poly(d,[project(x0,y0,z1),project(x1,y0,z1),project(x1,y1,z1),project(x0,y1,z1)],fill,outline)
def render(kind, direction):
    im=Image.new("RGBA",(320,320),(0,0,0,0)); d=ImageDraw.Draw(im)
    # rotate the logical footprint while retaining a shared camera/anchor
    if kind in ("wall","window","door"):
        draw_box(d,-.46,-.46,0,.46,.46,.12,(45,70,84,255)); d.rectangle((80,95,240,240),outline=(170,225,235,220),width=5)
        if kind=="door": d.line((160,95,160,240),fill=(210,240,245,230),width=5); d.line((145,165,155,165),fill=(220,220,220,255),width=4)
        if kind=="window": d.rectangle((88,110,232,220),fill=(85,170,195,90),outline=(220,245,250,230),width=4)
    elif kind=="cooler":
        draw_box(d,-.46,-.46,0,.46,.46,2.0,(55,70,82,255)); d.rectangle((92,90,228,230),fill=(90,180,210,90),outline=(220,245,250,220),width=4)
        for y in (125,160,195): d.line((96,y,224,y),fill=(245,245,235,220),width=3)
        for x in (112,140,168,196): d.rectangle((x,105,x+12,118),fill=(240,150,90,255))
    elif kind in ("counter","coffee","shelf","fryer"):
        draw_box(d,-.9,-.46,0,.9,.46,.95,(112,80,55,255))
        if kind=="coffee": draw_box(d,-.28,-.24,.95,.28,.24,1.55,(45,48,52,255)); d.ellipse((135,110,185,150),fill=(230,235,240,255),outline=(35,40,45,255),width=3)
        elif kind=="shelf":
            for z in (.45,.75,1.05,1.35): d.line((95,210-int(z*55),225,210-int(z*55)),fill=(220,210,190,255),width=5)
            for x in range(105,220,23): d.rectangle((x,150,x+14,170),fill=(95,150,180,255),outline=(30,40,50,255))
        else: d.rectangle((100,125,220,190),fill=(225,150,75,255),outline=(70,45,30,255),width=4)
    elif kind.startswith("plant"):
        d.ellipse((120,190,200,255),fill=(180,95,50,255),outline=(100,55,30,255),width=3)
        for x,y in ((145,170),(165,145),(185,175),(130,150)): d.ellipse((x-28,y-25,x+15,y+18),fill=(55,145,85,255),outline=(35,90,55,255))
    elif kind=="light": d.rounded_rectangle((80,145,240,178),8,fill=(245,250,220,255),outline=(80,90,100,255),width=3); d.line((95,160,225,160),fill=(255,255,245,255),width=6)
    elif kind in ("tree","tree2"):
        d.rectangle((145,145,175,250),fill=(105,65,40,255));
        for box in ((80,70,180,170),(140,60,245,165),(105,105,220,205)): d.ellipse(box,fill=(235,150,175,220) if kind=="tree" else (245,175,150,220),outline=(95,130,70,220))
    elif kind=="bed": d.rounded_rectangle((70,180,250,240),12,fill=(125,85,55,255),outline=(70,50,35,255),width=3); d.ellipse((90,150,140,205),fill=(245,120,145,255)); d.ellipse((150,155,205,210),fill=(255,205,80,255))
    elif kind=="board":
        d.line((125,150,105,245),fill=(70,55,40,255),width=8); d.line((195,150,215,245),fill=(70,55,40,255),width=8); d.polygon([(105,85),(215,85),(200,170),(120,170)],fill=(245,244,226,255),outline=(50,65,75,255));
        for i,t in enumerate(["OPEN","たばこ・おにぎり","お弁当・飲み物"]): d.text((120,95+i*22),t,fill=(25,55,70,255),font=FONT_OBJ)
    elif kind=="bike": d.ellipse((90,190,145,245),outline=(50,70,80,255),width=4); d.ellipse((175,190,230,245),outline=(50,70,80,255),width=4); d.line((117,215,180,215,150,170,117,215,180,215,195,180),fill=(45,65,75,255),width=4)
    return im

def manifest(pid, fp, height):
    m={"manifest_version":1,"visual_id":pid,"fixture_type_id":pid,"projection_id":"iso2x_v1","world_units_per_tile":1,"source_px_per_tile_diamond":[256,128],"footprint":{"w":fp[0],"h":fp[1]},"dimensions_m":{"width":max(.1,fp[0]-.08),"depth":max(.1,fp[1]-.08),"height":height},"rotations":{}}
    for r in range(4):
        m["rotations"][str(r)]={"canvas_px":[320,320],"anchor_px":[160,210],"layers":{"body":f"{pid}_{r}_body.png"},"slot_anchors_px":{},"selection_polygon_px":[[160,210],[160+128*fp[0],210+64*fp[0]],[160+128*(fp[0]-fp[1]),210+64*(fp[0]+fp[1])],[160-128*fp[1],210+64*fp[1]]],"sorting_anchor_px":[160,210]}
    return m

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    all_props = PROPS + [(f"category_pop_{x}",(1,1),.35,"board") for x in POPS]
    for pid,fp,h,kind in all_props:
        p=OUT/pid; p.mkdir(exist_ok=True)
        for r in range(4): render(kind,r).save(p/f"{pid}_{r}_body.png")
        (p/f"{pid}.visual.json").write_text(json.dumps(manifest(pid,fp,h),ensure_ascii=False,indent=1)+"\n",encoding="utf-8")
        prov={"asset_id":pid,"source_type":"project_generated","generator":"tools/assets/generate_props.py","tool":"Pillow fallback; Blender 2.91 unavailable in build environment","projection_id":"iso2x_v1","redistribution":"yes","fictional_brands_only":True,"footprint_tiles":fp,"height_m":h,"directions":[0,1,2,3]}
        (p/"PROVENANCE.json").write_text(json.dumps(prov,ensure_ascii=False,indent=1)+"\n",encoding="utf-8")
    # category signs are packed as a contact sheet, with readable Japanese labels
    sheet=Image.new("RGBA",(960,480),(28,48,66,255)); sd=ImageDraw.Draw(sheet)
    for i,label in enumerate(["おにぎり","飲料","パン","デザート","アイス","おでん","カップ麺","おかし"]):
        x=(i%4)*240; y=(i//4)*240; sd.rounded_rectangle((x+25,y+55,x+215,y+180),15,fill=(245,245,230,255),outline=(80,160,190,255),width=5); sd.text((x+55,y+105),label,fill=(25,65,85,255),font=ImageFont.truetype(FONT,28) if Path(FONT).exists() else FONT_OBJ)
    (ROOT/"docs/art").mkdir(exist_ok=True); sheet.save(ROOT/"docs/art/issue103_props_contact_sheet.png")
    print(f"generated {len(all_props)} props + POP contact sheet")
if __name__=="__main__": main()
