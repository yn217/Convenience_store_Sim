"""Non-destructive uniform-scale packaging and local image-only QA; no synthesis."""
from pathlib import Path
import hashlib, json, math
import cv2
import numpy as np
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
CANON = ROOT / 'assets/generated/fixtures/shelf_general/shelf_general_0_body.png'

def save_new(im, name):
    p = OUT / name
    if p.exists():
        raise FileExistsError(p)
    im.save(p)

def angles(im):
    a = np.array(im)
    rgb = a[:, :, :3].copy()
    rgb[a[:, :, 3] < 128] = 0
    edges = cv2.Canny(cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY), 60, 160)
    lines = cv2.HoughLinesP(edges, 1, np.pi/1800, 35, minLineLength=80, maxLineGap=8)
    values = []
    if lines is not None:
        for x1,y1,x2,y2 in lines[:,0]:
            if x2 < x1:
                x1,y1,x2,y2 = x2,y2,x1,y1
            angle = math.degrees(math.atan2(float(y2-y1),float(x2-x1)))
            if -33 < angle < -20:
                values.append((angle, math.hypot(float(x2-x1),float(y2-y1))))
    if not values:
        return None
    values.sort()
    half = sum(w for _,w in values)/2
    cumulative = 0
    for angle,w in values:
        cumulative += w
        if cumulative >= half:
            return round(angle,3)

def main(raw_a='a_refined_raw.png', suffix=''):
    canonical = Image.open(CANON).convert('RGBA')
    cb = canonical.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox()
    ca = angles(canonical)
    report = {'canonical':str(CANON.relative_to(ROOT)), 'canonical_sha256':hashlib.sha256(CANON.read_bytes()).hexdigest(), 'canvas_px':list(canonical.size), 'canonical_bbox_alpha128':cb, 'canonical_long_edge_angle_deg_hough':ca, 'method':'Uniform resampling and translation only. No warp, separate x/y scales, generated product compositing, or alpha repainting.', 'candidates':{}}
    panels = [('CANONICAL EMPTY',canonical)]
    for key in ('a','b'):
        raw_path = OUT / (raw_a if key == 'a' else 'b_generated_raw.png')
        raw = Image.open(raw_path).convert('RGBA')
        rb = raw.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox()
        scale = min((cb[2]-cb[0])/(rb[2]-rb[0]), (cb[3]-cb[1])/(rb[3]-rb[1]))
        tx = (cb[0]+cb[2])/2 - scale*(rb[0]+rb[2])/2
        ty = cb[3]-scale*rb[3]
        fitted = raw.transform(canonical.size, Image.Transform.AFFINE, (1/scale,0,-tx/scale,0,1/scale,-ty/scale), Image.Resampling.BICUBIC)
        final_name = f'shelf_general_full_r0_{key}{suffix}.png'
        save_new(fitted,final_name)
        a = np.array(fitted)
        alpha = a[:,:,3]
        occupied = alpha >= 128
        rgb = a[:,:,:3].astype(float)
        mx,mn = rgb.max(axis=2),rgb.min(axis=2)
        saturation = (mx-mn)/np.maximum(mx,1)
        colored = occupied & (saturation>0.30) & (mx>65)
        # Color coverage is a reproducible proxy, NOT semantic segmentation of products.
        bbox = fitted.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox()
        ang = angles(fitted)
        mask = np.array(canonical.getchannel('A'))>=128
        iou = np.count_nonzero(occupied & mask)/np.count_nonzero(occupied | mask)
        report['candidates'][key] = {'raw':raw_path.name,'final':final_name,'raw_size_px':list(raw.size),'raw_bbox_alpha128':rb,'uniform_scale':scale,'translation_px':[tx,ty], 'bbox_alpha128':bbox,'transparent_pixel_fraction':round(float(np.mean(alpha==0)),6),'partial_alpha_pixel_count':int(np.count_nonzero((alpha>0)&(alpha<255))),'border_alpha_max':int(max(alpha[0,:].max(),alpha[-1,:].max(),alpha[:,0].max(),alpha[:,-1].max())), 'opaque_pixel_count':int(occupied.sum()),'saturated_color_fraction_of_occupied_proxy':round(float(colored.sum()/occupied.sum()),6),'silhouette_iou_vs_empty':round(float(iou),6),'long_edge_angle_deg_hough':ang,'angle_delta_deg':None if ang is None else round(ang-ca,3), 'bbox_width_delta_px':(bbox[2]-bbox[0])-(cb[2]-cb[0]),'bbox_height_delta_px':(bbox[3]-bbox[1])-(cb[3]-cb[1]),'exact_geometry_guaranteed':False}
        panels.append((f'CANDIDATE {key.upper()} FULL/r0',fitted))
        overlay = Image.new('RGBA',canonical.size,(240,240,240,255))
        overlay.alpha_composite(fitted)
        contour = cv2.findContours((mask.astype(np.uint8)*255),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)[0]
        draw = ImageDraw.Draw(overlay)
        for c in contour:
            pts = [tuple(map(int,p[0])) for p in c]
            if len(pts)>2:
                draw.line(pts+[pts[0]],fill=(255,0,190,255),width=1)
        save_new(overlay,f'qa_overlay_{key}{suffix}.png')
    comparison = Image.new('RGB',(442*3,510),(235,235,235))
    draw = ImageDraw.Draw(comparison)
    for i,(label,im) in enumerate(panels):
        draw.text((i*442+12,10),label,fill=(30,30,30))
        for y in range(40,489,16):
            for x in range(i*442,(i+1)*442,16):
                if ((x-i*442)//16+(y-40)//16)%2:
                    draw.rectangle((x,y,min(x+15,(i+1)*442-1),min(y+15,488)),fill=(210,210,210))
        comparison.paste(im,(i*442,40),im)
    save_new(comparison,f'comparison{suffix}.png')
    (OUT/f'qa_metrics{suffix}.json').open('x',encoding='utf-8').write(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    hashes = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.is_file()}
    (OUT/f'SHA256SUMS{suffix}.json').open('x',encoding='utf-8').write(json.dumps(hashes,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__ == '__main__':
    import sys
    main(*sys.argv[1:])
