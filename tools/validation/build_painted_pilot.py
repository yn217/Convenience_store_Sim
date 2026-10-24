from __future__ import annotations
import json, shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
GEN = Path(r"C:\Users\yuuna\.codex\generated_images")
OUT = ROOT / "docs" / "art"

FRIDGE = GEN / "01a16b8c-ad5f-7010-a532-3835c53bc93f" / "exec-25adafc0-1819-434a-a3e1-e69afa8c8864.png"
SHELF = GEN / "01a16b8c-ad5f-7010-a532-3835c53bc93f" / "exec-bfeeae4c-cb9e-4b92-8efb-36d91324afa9.png"
STORE = GEN / "01a16b8c-ad5f-7010-a532-3835c53bc93f" / "exec-0cff2abf-1273-4158-a793-8c9f8321ed37.png"

def bbox(img: Image.Image):
    a = img.getchannel("A") if img.mode == "RGBA" else None
    if a:
        return a.getbbox()
    rgb = img.convert("RGB")
    # Generated non-alpha sheets use a near-black/near-white backdrop.
    mask = Image.new("L", rgb.size, 0)
    px, mp = rgb.load(), mask.load()
    for y in range(rgb.height):
        for x in range(rgb.width):
            r, g, b = px[x, y]
            if not ((r < 35 and g < 35 and b < 35) or (r > 248 and g > 248 and b > 248)):
                mp[x, y] = 255
    return mask.getbbox()

def paint_into_guide(sheet, cell, guide_path, out_path):
    guide = Image.open(guide_path).convert("RGBA")
    src = Image.open(sheet).convert("RGBA").crop(cell)
    sb = bbox(src)
    if not sb:
        raise RuntimeError(f"no generated subject in {sheet} {cell}")
    src = src.crop(sb)
    gb = guide.getchannel("A").getbbox()
    if not gb:
        raise RuntimeError(f"no guide alpha in {guide_path}")
    target = (gb[0], gb[1], gb[2] - gb[0], gb[3] - gb[1])
    src.thumbnail((target[2], target[3]), Image.Resampling.LANCZOS)
    layer = Image.new("RGBA", guide.size, (0, 0, 0, 0))
    x = target[0] + (target[2] - src.width) // 2
    y = target[1] + (target[3] - src.height) // 2
    layer.alpha_composite(src, (x, y))
    # Exact guide silhouette guarantees ground-footprint alignment.
    layer.putalpha(guide.getchannel("A"))
    layer.save(out_path)

def variant_manifest(src_path, out_dir, asset_id, fixture_id, layer_names, variant):
    data = json.loads(Path(src_path).read_text(encoding="utf-8"))
    data["visual_id"] = f"{asset_id}_{variant}"
    data["variant"] = variant
    data["state"] = "FULL"
    data["runtime_approved"] = False
    for rot in data["rotations"].values():
        for k, v in list(rot["layers"].items()):
            if k in layer_names:
                rot["layers"][k] = v.replace(f"{asset_id}_", f"{asset_id}_{variant}_")
    (out_dir / f"{asset_id}_{variant}.visual.json").write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")

def copy_shadow(src_dir, dst_dir, asset, directions, variant):
    for d in directions:
        for suffix in ["shadow.png", "glass_front.png"]:
            src = src_dir / f"{asset}_{d}_{suffix}"
            if src.exists(): shutil.copy2(src, dst_dir / f"{asset}_{variant}_{d}_{suffix}")

def provenance(dst, asset, prompt, guide):
    (dst / "PROVENANCE.json").write_text(json.dumps({"asset_id": asset+"_painted_v1", "source_type":"AI", "tool":"OpenAI built-in image_gen", "model":"built-in image generation", "prompt":prompt, "guide_images":[str(guide.relative_to(ROOT))], "edit_steps":["generated 4-view sheet", "cropped direction cells", "fit to guide alpha bounding box", "reused contract shadow/glass layers"], "license_or_usage_terms":"AI-generated project asset; fictional brands only", "generation_date":"2026-10-24", "runtime_approved":False}, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")

def main():
    variant="painted_v1"
    contact = Image.new("RGBA", (1600, 1000), (20, 35, 50, 255)); draw=ImageDraw.Draw(contact)
    jobs=[("fridge_drink", FRIDGE, 2, 2, "fixtures"), ("shelf_general", SHELF, 2, 2, "fixtures")]
    for asset, sheet, cols, rows, kind in jobs:
        src=ROOT/"assets/generated"/kind/asset
        dst=src/asset+"_painted_v1" if False else src
        # Variants remain in the existing asset directory to preserve loader discovery.
        for d in range(4):
            guide=src/f"{asset}_{d}_body.png"
            im=Image.open(sheet); cw,ch=im.width//2,im.height//2
            cell=((d%2)*cw,(d//2)*ch,(d%2+1)*cw,(d//2+1)*ch)
            out=src/f"{asset}_{variant}_{d}_body.png"; paint_into_guide(sheet,cell,guide,out)
            if d==0: contact.alpha_composite(Image.open(out).resize((260,310)),(20,20)); draw.text((20,335),asset,fill="white")
        copy_shadow(src,src,asset,range(4),variant)
        variant_manifest(src/f"{asset}_a.visual.json",src,asset,asset,{"body","shadow","glass_front"},variant)
        provenance(src,asset,f"Painted FULL {asset}, soft anime convenience-store illustration, dense fictional products, matching iso2x_v1 guide silhouette; no readable brands or logos.",src/f"{asset}_0_body.png")
    for asset in ["storefront_window","storefront_door","storefront_wall"]:
        src=ROOT/"assets/generated/props"/asset; im=Image.open(STORE); cw,ch=im.width//4,im.height//3; row={"storefront_window":0,"storefront_door":1,"storefront_wall":2}[asset]
        for d in range(4):
            guide=src/f"{asset}_{d}_body.png"; cell=(d*cw,row*ch,(d+1)*cw,(row+1)*ch)
            paint_into_guide(STORE,cell,guide,src/f"{asset}_{variant}_{d}_body.png")
        variant_manifest(src/f"{asset}.visual.json",src,asset,asset,{"body"},variant)
        provenance(src,asset,"Painted storefront piece, blue/white fascia and warm glass, fictional NOVA MART only, matching iso2x_v1 guide; no real logos.",guide)
    # Replace the draft contact with a complete old-vs-painted matrix (all directions).
    rows=[("fridge_drink",ROOT/"assets/generated/fixtures/fridge_drink"),("shelf_general",ROOT/"assets/generated/fixtures/shelf_general")]+[(a,ROOT/"assets/generated/props"/a) for a in ["storefront_window","storefront_door","storefront_wall"]]
    contact=Image.new("RGBA",(1600, len(rows)*230),(18,30,44,255)); cd=ImageDraw.Draw(contact)
    for ri,(asset,folder) in enumerate(rows):
        cd.text((8,ri*230+6),asset+"  old / painted",fill="white")
        for d in range(4):
            old=Image.open(folder/f"{asset}_{d}_body.png").convert("RGBA"); new=Image.open(folder/f"{asset}_{variant}_{d}_body.png").convert("RGBA")
            old.thumbnail((170,190)); new.thumbnail((170,190)); x=150+d*360
            contact.alpha_composite(old,(x,ri*230+28)); contact.alpha_composite(new,(x+175,ri*230+28)); cd.text((x+50,ri*230+205),f"d{d}",fill=(210,220,230,255))
    OUT.mkdir(parents=True,exist_ok=True); contact.save(OUT/"painted_pilot_contact.png")
    # Evidence: guide silhouette in red, painted body in cyan; exact alpha masks overlap.
    ov = Image.new("RGBA", (1200, 800), (245, 245, 245, 255)); od = ImageDraw.Draw(ov)
    items=[("fridge_drink", ROOT/"assets/generated/fixtures/fridge_drink"), ("shelf_general", ROOT/"assets/generated/fixtures/shelf_general"), ("storefront_window", ROOT/"assets/generated/props/storefront_window")]
    for i,(asset, folder) in enumerate(items):
        guide=Image.open(folder/f"{asset}_0_body.png").convert("RGBA"); painted=Image.open(folder/f"{asset}_{variant}_0_body.png").convert("RGBA")
        g=guide.getchannel("A"); p=painted.getchannel("A")
        red=Image.new("RGBA",guide.size,(255,40,40,0)); red.putalpha(g.point(lambda x:int(x*.65)))
        cyan=Image.new("RGBA",guide.size,(0,190,220,0)); cyan.putalpha(p.point(lambda x:int(x*.65)))
        combo=Image.alpha_composite(Image.alpha_composite(red,cyan),Image.new("RGBA",guide.size,(0,0,0,0)))
        combo.thumbnail((360,360)); ov.alpha_composite(combo,(i*390+10,30)); od.text((i*390+10,410),asset+" guide/painted overlay",fill=(20,30,40,255))
    ov.save(OUT/"painted_pilot_overlay_check.png")

if __name__ == "__main__": main()
