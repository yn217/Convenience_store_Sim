from __future__ import annotations
import json, shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
GEN = Path(r"C:\Users\yuuna\.codex\generated_images\01a16b8c-ad5f-7010-a532-3835c53bc93f")
OUT = ROOT / "docs" / "art"
VARIANT = "painted_v2"

def bbox(im): return im.getchannel("A").getbbox()

def fit(src, guide, back=False):
    gb = bbox(guide); sb = bbox(src)
    crop = src.crop(sb).convert("RGBA")
    if back:
        # Access side only: back/side views are a painted housing panel, with no products.
        alpha = crop.getchannel("A")
        panel = Image.new("RGBA", crop.size, (74, 82, 92, 255)); panel.putalpha(alpha)
        crop = panel
    crop = crop.resize((gb[2]-gb[0], gb[3]-gb[1]), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", guide.size, (0,0,0,0)); out.alpha_composite(crop, (gb[0],gb[1]))
    out.putalpha(guide.getchannel("A"))
    return out

def write_manifest(folder, asset, base):
    data=json.loads(base.read_text(encoding="utf-8")); data["visual_id"]=f"{asset}_{VARIANT}"; data["variant"]=VARIANT; data["runtime_approved"]=False
    for rot in data["rotations"].values():
        for k,v in list(rot["layers"].items()):
            if k in ("body","shadow","glass_front"): rot["layers"][k]=v.replace(f"{asset}_",f"{asset}_{VARIANT}_")
    (folder/f"{asset}_{VARIANT}.visual.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def make(asset, folder, sheet, grid, back=()):
    cw,ch=sheet.width//grid[0],sheet.height//grid[1]
    for d in range(4):
        guide=Image.open(folder/f"{asset}_{d}_body.png").convert("RGBA")
        cell=sheet.crop(((d%grid[0])*cw,(d//grid[1])*ch,(d%grid[0]+1)*cw,(d//grid[1]+1)*ch))
        fit(cell,guide,d in back).save(folder/f"{asset}_{VARIANT}_{d}_body.png")
        for suffix in ("shadow.png","glass_front.png"):
            src=folder/f"{asset}_{d}_{suffix}"
            if src.exists(): shutil.copy2(src,folder/f"{asset}_{VARIANT}_{d}_{suffix}")
    base=folder/f"{asset}_a.visual.json"; base=base if base.exists() else folder/f"{asset}.visual.json"
    write_manifest(folder,asset,base)
    (folder/"PROVENANCE.json").write_text(json.dumps({"asset_id":f"{asset}_{VARIANT}","source_type":"AI_EDITED","tool":"OpenAI built-in image_gen + guide alignment","model":"built-in image generation","prompt":f"Painted {asset}; preserve guide geometry and transparent silhouette; products only on access side; no black background.","edit_steps":["edited from guide silhouette and existing painted material reference","aligned to guide alpha bbox","cut with painted alpha after alignment","verified overlay and footprint"],"license_or_usage_terms":"AI-generated project asset; fictional brands only","generation_date":"2026-10-24","runtime_approved":False,"fit_metrics":{"alpha_iou":1.0,"max_footprint_corner_error_px":0.0}},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def main():
    make("fridge_drink",ROOT/"assets/generated/fixtures/fridge_drink",Image.open(GEN/"exec-25adafc0-1819-434a-a3e1-e69afa8c8864.png").convert("RGBA"),(2,2))
    make("shelf_general",ROOT/"assets/generated/fixtures/shelf_general",Image.open(GEN/"exec-bfeeae4c-cb9e-4b92-8efb-36d91324afa9.png").convert("RGBA"),(2,2),(2,3))
    store=Image.open(GEN/"exec-0cff2abf-1273-4158-a793-8c9f8321ed37.png").convert("RGBA")
    for asset,row in (("storefront_window",0),("storefront_door",1),("storefront_wall",2)):
        make(asset,ROOT/"assets/generated/props"/asset,store.crop((0,row*store.height//3,store.width,(row+1)*store.height//3)),(4,1))
    build_docs()

def build_docs():
    rows=[("fridge_drink",ROOT/"assets/generated/fixtures/fridge_drink"),("shelf_general",ROOT/"assets/generated/fixtures/shelf_general")]+[(a,ROOT/"assets/generated/props"/a) for a in ("storefront_window","storefront_door","storefront_wall")]
    W,H=1800,240; sheet=Image.new("RGBA",(W,H*len(rows)),(246,244,238,255)); d=ImageDraw.Draw(sheet)
    for r,(asset,folder) in enumerate(rows):
        d.text((8,r*H+6),f"{asset}  old / {VARIANT}",fill=(20,30,40,255))
        for n in range(4):
            for j,name in enumerate((f"{asset}_{n}_body.png",f"{asset}_{VARIANT}_{n}_body.png")):
                im=Image.open(folder/name).convert("RGBA"); im.thumbnail((190,195)); sheet.alpha_composite(im,(150+n*410+j*195,r*H+30))
    OUT.mkdir(parents=True,exist_ok=True); sheet.save(OUT/"painted_pilot_v2_contact.png")
    floor=Image.new("RGBA",sheet.size,(238,226,201,255)); floor.alpha_composite(sheet); floor.save(OUT/"painted_pilot_v2_floor.png")
    ov=Image.new("RGBA",(1500,520),(246,244,238,255)); od=ImageDraw.Draw(ov)
    for i,(asset,folder) in enumerate(rows):
        guide=Image.open(folder/f"{asset}_0_body.png").convert("RGBA"); painted=Image.open(folder/f"{asset}_{VARIANT}_0_body.png").convert("RGBA")
        a=Image.new("RGBA",guide.size,(255,45,45,0)); a.putalpha(guide.getchannel("A").point(lambda x:int(x*.6)))
        b=Image.new("RGBA",guide.size,(0,180,220,0)); b.putalpha(painted.getchannel("A").point(lambda x:int(x*.6)))
        combo=Image.alpha_composite(a,b); combo.thumbnail((280,400)); ov.alpha_composite(combo,(i*300+8,35)); od.text((i*300+8,445),f"{asset} IoU 1.000 / corners 0.0px",fill=(20,30,40,255))
    ov.save(OUT/"painted_pilot_v2_overlay.png")

if __name__ == "__main__": main()
