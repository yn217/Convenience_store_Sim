"""Generate a review-only 4-direction, 3-state fridge-drink sprite candidate.

This is a deterministic Pillow projection sketch, not a Blender calibrated render.
Run with Python 3 and Pillow installed. Outputs stay beside this script.
"""
from hashlib import sha256
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
SIZE = (768, 768)
ANCHOR = (384, 552)
SX, SY, SZ = 128.0, 64.0, 156.76734354
STATES = {"FULL": (8, 7, 7, 6), "HALF": (4, 3, 3, 2), "EMPTY": (0, 0, 0, 0)}
DRINKS = [
    ("tea_amber", (186, 119, 53, 255), (68, 101, 54, 255)),
    ("green_tea", (142, 174, 95, 255), (50, 89, 46, 255)),
    ("water", (120, 190, 218, 255), (35, 103, 157, 255)),
    ("coffee", (225, 214, 184, 255), (99, 66, 43, 255)),
    ("citrus_soda", (230, 197, 76, 255), (75, 119, 58, 255)),
]

def iso(x, y, z=0.0):
    return ANCHOR[0] + SX*(x-y), ANCHOR[1] + SY*(x+y) - SZ*z

def render(state, rotation):
    names = ("body", "products", "glass_front", "shadow")
    layers = {n: Image.new("RGBA", SIZE, (0, 0, 0, 0)) for n in names}
    def tr(x, y, z):
        # Rotate world-space mesh coordinates around the fixture center.
        return ((x,y,z),(1.0-y,x,z),(1.0-x,2.0-y,z),(y,1.0-x,z))[rotation]
    def P(x,y,z=0): return iso(*tr(x,y,z))
    def poly(draw, points, fill, outline=None, width=1):
        draw.polygon([P(*p) for p in points], fill=fill, outline=outline, width=width)
    sd = ImageDraw.Draw(layers["shadow"])
    poly(sd, [(0,0,0),(0,2,0),(1,2,0),(1,0,0)], (23,31,37,85))
    bd = ImageDraw.Draw(layers["body"])
    # Cabinet shell dimensions 0.92 x 1.92 x 2.00m; inner mesh extents are <= spec.
    poly(bd,[(.04,.04,0),(.96,.04,0),(.96,1.96,0),(.04,1.96,0)],(41,51,58,255),(24,31,36,255),2)
    poly(bd,[(.04,.04,2),(.96,.04,2),(.96,1.96,2),(.04,1.96,2)],(174,187,190,255),(76,91,97,255),2)
    poly(bd,[(.04,.04,0),(.04,1.96,0),(.04,1.96,2),(.04,.04,2)],(46,58,64,255),(23,31,36,255),2)
    poly(bd,[(.78,.04,.04),(.96,.04,.04),(.96,1.96,.04),(.78,1.96,.04)],(31,41,46,255))
    # Four lit shelf tiers; same structural pixels in all stock states.
    for z in (.46,.96,1.46,1.89):
        poly(bd,[(.10,.08,z),(.82,.08,z),(.82,1.92,z),(.10,1.92,z)],(179,195,192,235),(82,98,100,255),1)
        poly(bd,[(.14,.08,z+.015),(.18,.08,z+.015),(.18,1.92,z+.015),(.14,1.92,z+.015)],(255,235,175,210))
    # Dark gasket and cabinet edge on customer-facing E side.
    poly(bd,[(.86,.04,.06),(.96,.04,.06),(.96,1.96,.06),(.86,1.96,.06)],(27,37,43,255))
    pd = ImageDraw.Draw(layers["products"])
    for row,z in enumerate((.50,1.00,1.50,1.92)):
        count = STATES[state][row]
        for i in range(count):
            slots = max(1, count-1)
            y = .18 + i*(1.64/slots) if count > 1 else .92
            name, liquid, label = DRINKS[(i+row) % len(DRINKS)]
            # 500ml PET forms (0.068m diameter x 0.225m tall) projected as faceted bottles.
            x=.56
            poly(pd,[(x-.045,y-.045,z),(x+.045,y-.045,z),(x+.052,y-.035,z+.035),(x+.052,y-.035,z+.19),(x+.032,y-.035,z+.225),(x-.032,y-.035,z+.225),(x-.052,y-.035,z+.19),(x-.052,y-.035,z+.035)],liquid,(34,48,48,255),1)
            poly(pd,[(x-.05,y-.046,z+.08),(x+.05,y-.046,z+.08),(x+.05,y-.046,z+.15),(x-.05,y-.046,z+.15)],label,(28,40,42,255),1)
            # Simple fictional motif, deliberately no glyphs or logos.
            poly(pd,[(x-.018,y-.047,z+.105),(x,y-.047,z+.135),(x+.018,y-.047,z+.105),(x,y-.047,z+.09)],(244,231,190,255))
            poly(pd,[(x-.018,y-.04,z+.225),(x+.018,y-.04,z+.225),(x+.016,y-.04,z+.245),(x-.016,y-.04,z+.245)],(226,230,216,255))
    gd=ImageDraw.Draw(layers["glass_front"])
    poly(gd,[(.82,.08,.08),(.95,.08,.08),(.95,1.92,.08),(.82,1.92,.08)],(148,216,229,39),(195,237,241,155),2)
    poly(gd,[(.84,.12,.18),(.87,.12,.18),(.87,1.88,.18),(.84,1.88,.18)],(242,252,255,80))
    poly(gd,[(.94,.08,.08),(.98,.08,.08),(.98,1.92,.08),(.94,1.92,.08)],(34,51,59,240),(15,25,30,255),1)
    composite=Image.new("RGBA",SIZE,(0,0,0,0))
    for name in ("shadow","body","products","glass_front"): composite.alpha_composite(layers[name])
    return layers,composite

def main():
    index={}
    for state in STATES:
        for r in range(4):
            layers,comp=render(state,r); stem=f"fridge_drink_{state.lower()}_r{r}"
            paths={}
            for layer,img in layers.items():
                fn=f"{stem}_{layer}.png"; img.save(ROOT/fn,optimize=True); paths[layer]=fn
            composite=f"{stem}.png"; comp.save(ROOT/composite,optimize=True)
            index[f"{state.lower()}_r{r}"]={"state":state,"rotation":r,"canvas_px":list(SIZE),"anchor_px":list(ANCHOR),"layers":paths,"composite":composite,"composition_order":["shadow","body","products","glass_front"]}
    manifest={"manifest_version":1,"candidate_id":"fridge_drink_inventory_candidate_v2","fixture_type_id":"fridge_drink","projection_id":"iso2x_v1","calibration_status":"UNVERIFIED_PILLOW_PROJECTION_SKETCH","dimensions_m":{"width":.92,"depth":1.92,"height":2.00},"footprint":{"w":1,"h":2},"front":"E","source_px_per_tile":[256,128],"canvas_px":list(SIZE),"anchor_px":list(ANCHOR),"states":["FULL","HALF","EMPTY"],"rotations":[0,1,2,3],"rotation_state_assets":index,"runtime_approved":False}
    (ROOT/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    pngs=sorted(ROOT.glob("*.png")); prov={"runtime_approved":False,"asset_type":"candidate_only","generator":"OpenAI built-in ImageGen package reference + deterministic Pillow geometry compositor","imagegen_input":"fictional_drink_package_reference.png","imagegen_prompt":"Five fictional Japanese convenience-store drink package concepts (amber tea, green tea, water, coffee, citrus soda), no readable text or trademarks; generated 2026-10-24. Used as design reference only; this 2D package board is not projected onto calibrated 3D meshes.","blender_used":False,"projection_calibrated":False,"dimensions_m":[.92,1.92,2.00],"unverified_points":["Blender 45-degree azimuth/30-degree elevation numerical calibration not run; Blender executable unavailable in this environment.","Pillow geometry is a visual candidate, not a conforming 3D render.","No Godot runtime or zoom/depth integration verification.","Human visual acceptance pending."],"sha256":{p.name:sha256(p.read_bytes()).hexdigest() for p in pngs}}
    (ROOT/"provenance.json").write_text(json.dumps(prov,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    (ROOT/"SHA256SUMS.txt").write_text("".join(f"{sha256(p.read_bytes()).hexdigest()}  {p.name}\n" for p in pngs),encoding="utf-8")
    # Compact 3-state x 4-rotation review sheet from composites.
    from PIL import ImageFont
    thumb=(320,320); pad=20; head=38
    sheet=Image.new("RGBA",(pad+4*(thumb[0]+pad),head+3*(thumb[1]+head+pad)),(237,240,241,255)); d=ImageDraw.Draw(sheet)
    for si,state in enumerate(("FULL","HALF","EMPTY")):
        d.text((pad,head+si*(thumb[1]+head+pad)),state,fill=(26,38,45,255))
        for r in range(4):
            x=pad+r*(thumb[0]+pad); y=head+si*(thumb[1]+head+pad)+head
            d.text((x,y-23),f"r{r}",fill=(26,38,45,255))
            im=Image.open(ROOT/f"fridge_drink_{state.lower()}_r{r}.png").convert("RGBA"); im.thumbnail(thumb,Image.Resampling.LANCZOS)
            sheet.alpha_composite(im,(x+(thumb[0]-im.width)//2,y+(thumb[1]-im.height)//2))
    sheet.convert("RGB").save(ROOT/"contact_sheet.png",quality=95)
if __name__=="__main__": main()
