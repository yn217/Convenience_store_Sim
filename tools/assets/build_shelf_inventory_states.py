"""Crop Issue #91 Blender renders with one shared crop/anchor per rotation and write manifests."""
import argparse
import hashlib
import json
import os
import shutil

from PIL import Image, ImageDraw

STATES = ("FULL", "HALF", "EMPTY")
LAYERS = ("body", "products", "shadow")
PADDING = 8


def bbox(img):
    return img.getchannel("A").getbbox()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--raw", required=True)
    p.add_argument("--out", required=True)
    a = p.parse_args()
    raw, out = os.path.abspath(a.raw), os.path.abspath(a.out)
    os.makedirs(out, exist_ok=True)
    info = json.load(open(os.path.join(raw, "render_info.json"), encoding="utf-8"))
    fixture = info["fixture_type_id"]
    dimensions = info["dimensions_m"]
    footprint = info["footprint"]
    render_dir = os.path.join(raw, "raw", "raw")
    calibration_src = os.path.join(render_dir, "calibration.png")
    if os.path.isfile(calibration_src):
        shutil.copy2(calibration_src, os.path.join(out, "calibration.png"))
    canvas = tuple(info["canvas_px"])
    origin = info["origin_px"]
    w, h = canvas
    manifest = {"manifest_version": 1, "visual_id": info["visual_id"],
        "fixture_type_id": fixture, "projection_id": "iso2x_v1", "world_units_per_tile": 1,
        "source_px_per_tile_diamond": [256, 128], "footprint": footprint,
        "dimensions_m": dimensions,
        "front": "E", "runtime_approved": False, "states": {}}
    composites = {}
    shared_crops = {}
    for r in range(4):
        boxes = []
        for state in STATES:
            for layer in LAYERS:
                im = Image.open(os.path.join(render_dir, "%s_%s_r%d_%s.png" % (fixture, state.lower(), r, layer))).convert("RGBA")
                if bbox(im): boxes.append(bbox(im))
        shared_crops[r] = (max(0,min(b[0] for b in boxes)-PADDING), max(0,min(b[1] for b in boxes)-PADDING),
                           min(w,max(b[2] for b in boxes)+PADDING), min(h,max(b[3] for b in boxes)+PADDING))
    for state in STATES:
        manifest["states"][state] = {"rotations": {}}
        for r in range(4):
            images = {layer: Image.open(os.path.join(render_dir, "%s_%s_r%d_%s.png" % (fixture, state.lower(), r, layer))).convert("RGBA") for layer in LAYERS}
            left, top, right, bottom = shared_crops[r]
            crop = shared_crops[r]
            anchor = [round(origin[0]-left, 2), round(origin[1]-top, 2)]
            layer_paths = {}
            for layer, im in images.items():
                name = "%s_%s_r%d_%s.png" % (fixture, state.lower(), r, layer)
                im.crop(crop).save(os.path.join(out, name), optimize=True)
                layer_paths[layer] = name
            comp = Image.new("RGBA", (right-left, bottom-top), (0,0,0,0))
            for layer in ("shadow", "body", "products"):
                comp = Image.alpha_composite(comp, Image.open(os.path.join(out, layer_paths[layer])).convert("RGBA"))
            cname = "%s_%s_r%d_composite.png" % (fixture, state.lower(), r)
            comp.save(os.path.join(out, cname), optimize=True)
            layer_paths["composite"] = cname
            selection = [[round(anchor[0]+x,2), round(anchor[1]+y,2)] for x,y in ((0,0),(128,64),(0,128),(-128,64))]
            manifest["states"][state]["rotations"][str(r)] = {"canvas_px":[right-left,bottom-top], "anchor_px":anchor,
                "layers":layer_paths,"selection_polygon_px":selection,"sorting_anchor_px":anchor}
            composites[(state,r)] = comp
    with open(os.path.join(out,"manifest.json"),"w",encoding="utf-8",newline="\n") as f:
        json.dump(manifest,f,ensure_ascii=False,indent=2); f.write("\n")
    # Review board: state rows, four true 3D rotations per row, aligned by the common world-origin anchor.
    cellw, cellh, margin = 430, 500, 18
    sheet=Image.new("RGB",(margin+4*(cellw+margin),margin+3*(cellh+margin)),(219,222,222))
    draw=ImageDraw.Draw(sheet)
    for si,state in enumerate(STATES):
        for r in range(4):
            rot=manifest["states"][state]["rotations"][str(r)]
            ax,ay=rot["anchor_px"]
            x=margin+r*(cellw+margin)+cellw//2-int(ax)
            y=margin+si*(cellh+margin)+cellh//2-int(ay)
            sheet.paste(composites[(state,r)],(x,y),composites[(state,r)])
            draw.text((margin+r*(cellw+margin)+8,margin+si*(cellh+margin)+8),"%s / r%d"%(state,r),fill=(20,30,40))
            draw.line((x-9,y,x+9,y),fill=(200,30,30),width=2); draw.line((x,y-9,x,y+9),fill=(200,30,30),width=2)
    sheet.save(os.path.join(out,"contact_sheet.png"))
    # Hash source settings and deliverables. Runtime approval remains false pending in-game review.
    files=sorted(n for n in os.listdir(out) if n.lower().endswith(".png") or n=="manifest.json")
    prov={"issue":"#91","fixture_type_id":fixture,"renderer":"Blender %s / BLENDER_EEVEE"%info["blender_version"],
        "source_generator":"tools/assets/render_shelf_inventory_states.py","crop_generator":"tools/assets/build_shelf_inventory_states.py",
        "projection_id":"iso2x_v1","azimuth_deg":45,"elevation_deg":30,"source_px_per_tile_diamond":[256,128],
        "physical_dimensions_m":dimensions,"footprint":footprint,"front":"E",
        "states":{"FULL":"8 packages per shelf row","HALF":"4 packages per shelf row","EMPTY":"0 packages"},
        "rotations":[0,1,2,3],"calibration":{"file":"calibration.png"},"origin_px":info["origin_px"],
        "calibration_measured":False,"calibration_validation":"validation_report.json","runtime_approved":False,"third_party_assets":False,
        "notes":"This builder records the calibration chart and origin but does not measure it. Run validate_inventory_state_candidate.py; its separate report records measured projection offsets and layer consistency. Mesh silhouette and runtime rendering remain unverified.",
        "sha256":{n:hashlib.sha256(open(os.path.join(out,n),"rb").read()).hexdigest() for n in files}}
    with open(os.path.join(out,"provenance.json"),"w",encoding="utf-8",newline="\n") as f:
        json.dump(prov,f,ensure_ascii=False,indent=2); f.write("\n")
    print("BUILT",len(files)-1,"PNG/manifest files; contact_sheet.png")


if __name__=="__main__": main()
