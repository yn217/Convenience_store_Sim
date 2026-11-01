"""Reproducible Issue #111 exterior prop sprites (Pillow, iso2x_v1 contract)."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/generated/props"
FONT_PATH = "C:/Windows/Fonts/meiryo.ttc"
try: FONT = ImageFont.truetype(FONT_PATH, 22)
except OSError: FONT = ImageFont.load_default()
try: SMALL = ImageFont.truetype(FONT_PATH, 15)
except OSError: SMALL = FONT

ASSETS = {
    "vending_machine": ((1,1), 1.85, "vending"), "bench": ((2,1), .85, "bench"),
    "trash_recycle_bins": ((2,1), 1.05, "bins"), "nobori_banner_obento": ((1,1), 2.0, "banner_obento"),
    "nobori_banner_ice": ((1,1), 2.0, "banner_ice"), "nobori_banner_coffee": ((1,1), 2.0, "banner_coffee"),
    "car_stop_bollard": ((2,1), .35, "bollard"), "parking_lot_straight": ((1,1), .02, "straight"),
    "parking_lot_corner": ((1,1), .02, "corner"), "parking_lot_end": ((1,1), .02, "end"),
    "parking_lot_crosswalk": ((1,1), .02, "crosswalk"), "pole_sign": ((1,1), 3.8, "pole_sign"),
    "street_lamp": ((1,1), 2.8, "lamp"), "parked_car_blue": ((2,1), 1.55, "car_blue"),
    "parked_car_red": ((2,1), 1.55, "car_red"), "poster_board": ((1,1), 1.45, "poster"),
}

def text(d, xy, s, font=FONT, fill=(25,45,60,255), anchor="mm"): d.text(xy, s, font=font, fill=fill, anchor=anchor)
def render(kind, rotation):
    im=Image.new("RGBA",(320,320),(0,0,0,0)); d=ImageDraw.Draw(im)
    # Shared ground anchor at (160,210); front-facing details are intentionally legible.
    if kind == "vending":
        d.rounded_rectangle((85,55,235,215),10,fill=(225,232,238,255),outline=(35,65,90,255),width=5)
        d.rectangle((98,72,222,145),fill=(100,205,225,255),outline=(35,65,90,255),width=3)
        for x,c in zip((110,140,170,200),((245,90,90,255),(245,205,65,255),(85,180,110,255),(245,150,65,255))): d.rounded_rectangle((x,90,x+20,125),4,fill=c)
        d.rectangle((98,154,222,198),fill=(35,50,65,255)); text(d,(160,177),"NOVA DRINK",SMALL,(220,245,250,255))
        d.ellipse((145,208,175,222),fill=(45,55,65,255))
    elif kind == "bench":
        d.rectangle((72,120,248,155),fill=(155,95,48,255),outline=(65,45,35,255),width=4); d.rectangle((72,165,248,198),fill=(175,110,58,255),outline=(65,45,35,255),width=4)
        d.line((95,198,85,240),fill=(55,65,70,255),width=8); d.line((225,198,235,240),fill=(55,65,70,255),width=8)
    elif kind == "bins":
        for x,label,c in ((85,"燃えるゴミ",(70,110,120,255)),(145,"缶",(80,95,110,255)),(205,"ペットボトル",(75,140,105,255))):
            d.rounded_rectangle((x,125,x+48,210),6,fill=c,outline=(35,50,60,255),width=3); d.ellipse((x+10,115,x+38,135),fill=(35,45,55,255)); text(d,(x+24,170),label,SMALL,(245,250,245,255))
    elif kind.startswith("banner"):
        d.line((160,70,160,245),fill=(70,55,45,255),width=5); d.polygon([(130,75),(190,75),(190,190),(130,205)],fill=(245,78,78,255),outline=(95,40,40,255)); label={"banner_obento":"お弁当","banner_ice":"アイス","banner_coffee":"コーヒー"}[kind]; text(d,(160,125),label,FONT,(255,250,220,255))
    elif kind == "bollard":
        d.rounded_rectangle((75,190,245,225),5,fill=(195,195,185,255),outline=(100,100,95,255),width=3); d.line((110,195,110,130,150,110,190,130,190,195),fill=(235,190,35,255),width=12); d.line((110,195,110,130,150,110,190,130,190,195),fill=(80,75,55,255),width=3)
    elif kind in ("straight","corner","end","crosswalk"):
        d.polygon([(25,210),(160,145),(295,210),(160,278)],fill=(58,65,70,255),outline=(38,45,50,255))
        if kind=="straight": d.line((45,210,275,210),fill=(245,245,235,255),width=8)
        elif kind=="corner": d.line((65,225,160,178,250,225),fill=(245,245,235,255),width=8)
        elif kind=="end": d.line((70,225,250,225),fill=(245,245,235,255),width=8); d.line((160,160,160,225),fill=(245,245,235,255),width=8)
        else:
            for x in range(90,241,30): d.line((x,185,x-38,235),fill=(245,245,235,255),width=8)
    elif kind == "pole_sign":
        d.rectangle((153,75,167,240),fill=(70,75,80,255)); d.rounded_rectangle((75,45,245,150),8,fill=(35,95,170,255),outline=(235,245,250,255),width=5); text(d,(160,75),"コンビニ24",FONT,(255,255,255,255));
        for y,s,c in ((105,"たばこ",(220,55,65,255)),(125,"酒",(50,80,190,255)),(145,"ATM",(185,55,180,255))): d.rectangle((95,y,225,y+20),fill=c); text(d,(160,y+10),s,SMALL,(255,255,255,255))
    elif kind == "lamp":
        d.line((160,215,160,85),fill=(55,65,70,255),width=8); d.line((160,105,205,85),fill=(55,65,70,255),width=6); d.ellipse((190,75,220,98),fill=(255,235,150,255),outline=(55,65,70,255),width=3)
    elif kind.startswith("car_"):
        col=(75,145,210,255) if kind=="car_blue" else (210,70,70,255); d.rounded_rectangle((50,150,270,225),22,fill=col,outline=(35,45,55,255),width=5); d.polygon([(95,150),(125,115),(205,115),(240,150)],fill=col,outline=(35,45,55,255)); d.polygon([(132,122),(158,122),(158,148),(112,148)],fill=(170,215,225,220)); d.polygon([(165,122),(198,122),(225,148),(165,148)],fill=(170,215,225,220));
        for x in (95,220): d.ellipse((x,205,x+35,240),fill=(35,40,45,255),outline=(210,215,220,255),width=4)
    elif kind == "poster":
        d.line((115,165,95,245),fill=(65,55,45,255),width=8); d.line((205,165,225,245),fill=(65,55,45,255),width=8); d.polygon([(95,60),(225,60),(210,175),(110,175)],fill=(250,248,228,255),outline=(40,60,75,255)); text(d,(160,95),"新生活",FONT,(220,75,75,255)); text(d,(160,130),"フェア",FONT,(40,100,170,255)); text(d,(160,158),"NOVA MART",SMALL,(40,60,75,255))
    return im

def manifest(pid, fp, height):
    m={"manifest_version":1,"visual_id":pid,"fixture_type_id":pid,"projection_id":"iso2x_v1","world_units_per_tile":1,"source_px_per_tile_diamond":[256,128],"footprint":{"w":fp[0],"h":fp[1]},"dimensions_m":{"width":max(.1,fp[0]-.08),"depth":max(.1,fp[1]-.08),"height":height},"rotations":{}}
    for r in range(4): m["rotations"][str(r)]={"canvas_px":[320,320],"anchor_px":[160,210],"layers":{"body":f"{pid}_{r}_body.png"},"slot_anchors_px":{},"selection_polygon_px":[[160,210],[160+128*fp[0],210+64*fp[0]],[160+128*(fp[0]-fp[1]),210+64*(fp[0]+fp[1])],[160-128*fp[1],210+64*fp[1]]],"sorting_anchor_px":[160,210]}
    return m

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for pid,(fp,h,kind) in ASSETS.items():
        p=OUT/pid; p.mkdir(exist_ok=True)
        for r in range(4): render(kind,r).save(p/f"{pid}_{r}_body.png")
        (p/f"{pid}.visual.json").write_text(json.dumps(manifest(pid,fp,h),ensure_ascii=False,indent=1)+"\n",encoding="utf-8")
        (p/"PROVENANCE.json").write_text(json.dumps({"asset_id":pid,"source_type":"project_generated","generator":"tools/assets/generate_exterior_props.py","tool":"Pillow; deterministic primitives","projection_id":"iso2x_v1","redistribution":"yes","fictional_brands_only":True,"footprint_tiles":fp,"height_m":h,"directions":[0,1,2,3]},ensure_ascii=False,indent=1)+"\n",encoding="utf-8")
    print(f"generated {len(ASSETS)} exterior props")
if __name__ == "__main__": main()
