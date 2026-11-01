"""Local image QA only. Never changes a generated sprite or existing asset."""
from pathlib import Path
import hashlib, json, math, sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
GUIDE = ROOT / 'assets/generated/fixtures/shelf_noodle/shelf_noodle_0_body.png'
REFINED = '--refined' in sys.argv
SUFFIX = '_refined' if REFINED else ''
OUTPUT_SUFFIX = '_final' if REFINED else ''

def measure(path):
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im)[:, :, 3]
    bbox = Image.fromarray((a > 8).astype('uint8') * 255).getbbox()
    rgb = Image.new('RGB', im.size, (75, 75, 75))
    rgb.paste(im, mask=im.getchannel('A'))
    edges = cv2.Canny(cv2.cvtColor(np.asarray(rgb), cv2.COLOR_RGB2GRAY), 60, 160)
    lines = cv2.HoughLinesP(edges, 1, np.pi/180, 60,
                            minLineLength=min(im.size)/5, maxLineGap=15)
    segments = []
    for x1, y1, x2, y2 in ([] if lines is None else lines[:, 0]):
        if x2 == x1:
            continue
        slope = float((y2-y1)/(x2-x1))
        if -.9 < slope < -.15:
            segments.append(dict(length_px=round(math.hypot(x2-x1,y2-y1),2),
                                 slope=round(slope,5), xyxy=[int(v) for v in (x1,y1,x2,y2)]))
    segments.sort(key=lambda x:x['length_px'], reverse=True)
    segments = segments[:24]
    slope = float(np.median([s['slope'] for s in segments])) if segments else None
    border = np.concatenate([a[0], a[-1], a[:,0], a[:,-1]])
    return dict(canvas_px=list(im.size), mode=Image.open(path).mode,
                alpha_bbox_threshold8_xyxy_exclusive=list(bbox),
                bbox_aspect=(bbox[2]-bbox[0])/(bbox[3]-bbox[1]),
                transparent_pixel_fraction=float(np.mean(a==0)),
                partial_alpha_pixel_fraction=float(np.mean((a>0)&(a<255))),
                near_opaque_pixel_fraction=float(np.mean(a>=250)),
                nontransparent_border_pixels=int(np.sum(border>8)),
                long_axis_slope_median=slope, long_edge_segments=segments,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())

paths = [GUIDE, HERE/f'shelf_noodle_full_r0_candidate_a{SUFFIX}.png', HERE/f'shelf_noodle_full_r0_candidate_b{SUFFIX}.png']
result = {p.name:measure(p) for p in paths}
ref = result[GUIDE.name]
for p in paths[1:]:
    m = result[p.name]
    m['slope_target_interval'] = [-.53, -.47]
    m['slope_pass'] = m['long_axis_slope_median'] is not None and -.53 <= m['long_axis_slope_median'] <= -.47
    m['bbox_aspect_relative_error'] = m['bbox_aspect']/ref['bbox_aspect']-1
    m['caution'] = 'Hough median is an automatic diagnostic, not proof of exact shelf geometry. Stock can extend above canonical silhouette.'

# Uniform-fit previews only; source sprites remain byte-for-byte untouched.
panels = []
for path in paths:
    im = Image.open(path).convert('RGBA')
    box = tuple(result[path.name]['alpha_bbox_threshold8_xyxy_exclusive'])
    crop = im.crop(box)
    factor = min(410/crop.width, 510/crop.height)
    size = (round(crop.width*factor), round(crop.height*factor))
    thumb = crop.resize(size, Image.Resampling.LANCZOS)
    panel = Image.new('RGBA', (460,600), (0,0,0,255))
    draw = ImageDraw.Draw(panel)
    for y in range(45,600,16):
        for x in range(0,460,16):
            c = 215 if (x//16+y//16)%2 else 238
            draw.rectangle((x,y,x+15,y+15),fill=(c,c,c,255))
    title = 'CANONICAL EMPTY' if path==GUIDE else ('A: FULL / r0' if '_candidate_a' in path.name else 'B: FULL / r0')
    draw.text((15,15),title,fill='white')
    panel.alpha_composite(thumb,((460-size[0])//2,565-size[1]))
    panels.append(panel)
comparison = Image.new('RGB',(1380,600),'white')
for i,panel in enumerate(panels): comparison.paste(panel.convert('RGB'),(460*i,0))
comparison.save(HERE/f'comparison_canonical_a_b{OUTPUT_SUFFIX}.png')
result['_method'] = 'Canny 60/160; HoughLinesP rho1 theta1degree threshold60 minimum_length=min(canvas)/5 gap15; longest 24 negative diagonals in (-.9,-.15). Comparison uses uniform scaling and translation only; no asset transformations.'
(HERE/f'qa_metrics{OUTPUT_SUFFIX}.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({name:{k:v for k,v in m.items() if k not in ('long_edge_segments',)} for name,m in result.items() if isinstance(m,dict)},indent=2))
