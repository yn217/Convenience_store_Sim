"""Limited sprite QA and whole-image canvas normalization; no merchandise compositing."""
from pathlib import Path
import hashlib, json, math
import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SIZE = (442, 450)
ANCHOR = (285, 303)

def measure(path):
    im = Image.open(path).convert('RGBA')
    ar = np.asarray(im)
    a = ar[:, :, 3]
    mask = (a > 8).astype('uint8')
    bbox = Image.fromarray(mask * 255).getbbox()
    bg = Image.new('RGBA', im.size, (65,65,65,255))
    bg.alpha_composite(im)
    edges = cv2.Canny(cv2.cvtColor(np.asarray(bg)[:,:,:3], cv2.COLOR_RGB2GRAY),60,160)
    lines = cv2.HoughLinesP(edges,1,np.pi/180,45,minLineLength=im.width*.28,maxLineGap=8)
    segments = []
    for x1,y1,x2,y2 in ([] if lines is None else lines[:,0]):
        if x1 == x2: continue
        slope = float((y2-y1)/(x2-x1))
        if -.7 < slope < -.3:
            segments.append({'xyxy':[int(x1),int(y1),int(x2),int(y2)],'length_px':round(math.hypot(x2-x1,y2-y1),3),'slope':round(slope,6)})
    segments.sort(key=lambda s:s['length_px'],reverse=True)
    seg = segments[:12]
    slope = float(np.median([s['slope'] for s in seg])) if seg else None
    border = np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
    n, labels, stats, centroids = cv2.connectedComponentsWithStats(mask,8)
    return {'canvas_px':list(im.size),'alpha_bbox_gt8_xyxy_exclusive':list(bbox),
        'transparent_fraction':float(np.mean(a==0)),'partial_alpha_fraction':float(np.mean((a>0)&(a<255))),
        'opaque_fraction':float(np.mean(a==255)),'border_pixels_alpha_gt8':int(np.sum(border>8)),
        'components_area_ge4':int(sum(s[cv2.CC_STAT_AREA]>=4 for s in stats[1:])),
        'long_edge_slope_median':slope,'target_slope':-.5,
        'slope_diagnostic_pass':slope is not None and abs(slope+.5)<=.03,
        'long_edge_segments':seg,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

paths = [HERE/'input_guide.png']
transforms = {}
for variant in ['a','b']:
    source = HERE/f'original_{variant}.png'
    im = Image.open(source).convert('RGBA')
    scale = min(SIZE[0]/im.width,SIZE[1]/im.height)
    dims = (round(im.width*scale),round(im.height*scale))
    offset = ((SIZE[0]-dims[0])//2,(SIZE[1]-dims[1])//2)
    final = Image.new('RGBA',SIZE)
    # Resample the entire generated image as one object, preserving generated alpha.
    final.paste(im.resize(dims,Image.Resampling.LANCZOS),offset)
    out = HERE/f'shelf_bread_full_r0_candidate_{variant}.png'
    final.save(out)
    transforms[variant] = {'source_canvas_px':list(im.size),'uniform_scale':scale,'rounded_size_px':list(dims),'offset_px':list(offset),'operations':'whole-image uniform resize and transparent canvas only; no crop, warp, alpha removal or individual product placement','anchor_px':list(ANCHOR)}
    paths.append(out)

metrics = {p.name:measure(p) for p in paths}
ref = metrics['input_guide.png']
for p in paths[1:]:
    m = metrics[p.name]
    m['bbox_delta_from_guide_px'] = [a-b for a,b in zip(m['alpha_bbox_gt8_xyxy_exclusive'],ref['alpha_bbox_gt8_xyxy_exclusive'])]
    m['anchor_px'] = list(ANCHOR)
    m['anchor_status'] = 'canonical metadata retained; generated geometry alignment evaluated by bbox and long edges, not an exact vertex proof'
    rb = ref['alpha_bbox_gt8_xyxy_exclusive']
    mb = m['alpha_bbox_gt8_xyxy_exclusive']
    m['bbox_width_ratio_to_guide'] = (mb[2]-mb[0])/(rb[2]-rb[0])
# Corresponding canopy rear long edge, visually identified at canonical resolution.
# Hough line lengths are NOT comparable across images because detections fragment.
landmarks = {'input_guide.png':[(38,132),(285,8)],
    'shelf_bread_full_r0_candidate_a.png':[(39,131),(283,7)],
    'shelf_bread_full_r0_candidate_b.png':[(36,136),(288,8)]}
ref_length = math.dist(*landmarks['input_guide.png'])
for name, points in landmarks.items():
    dx,dy = points[1][0]-points[0][0],points[1][1]-points[0][1]
    metrics[name]['corresponding_canopy_edge'] = {'endpoints_px':points,'method':'visual landmark estimate; uncertainty approximately 2 canonical pixels per endpoint','length_px':math.dist(*points),'length_ratio_to_guide':math.dist(*points)/ref_length,'slope':dy/dx}
for v in ['a','b']: metrics[f'original_{v}.png'] = measure(HERE/f'original_{v}.png')
metrics['_method'] = 'Alpha threshold 8; Canny 60/160; Hough longest 12 negative diagonals in (-.7,-.3). Slope tolerance .03 is diagnostic only; no claim of exact geometric match. Same-scale comparison shows complete canonical canvases at 1:1, without bbox-fitting.'
metrics['_normalization'] = transforms
(HERE/'qa_metrics.json').write_text(json.dumps(metrics,ensure_ascii=False,indent=2),encoding='utf-8')

comparison = Image.new('RGBA',(3*466,506),(37,40,46,255))
draw = ImageDraw.Draw(comparison)
for i,p in enumerate(paths):
    x0 = i*466+12
    draw.text((x0,12),['GUIDE  442x450','A  FULL/r0  442x450','B  FULL/r0  442x450'][i],fill='white')
    for y in range(40,490,12):
        for x in range(x0,x0+442,12):
            c = 215 if ((x-x0)//12+(y-40)//12)%2 else 238
            draw.rectangle((x,y,min(x+11,x0+441),min(y+11,489)),fill=(c,c,c,255))
    comparison.alpha_composite(Image.open(p).convert('RGBA'),(x0,40))
    ax,ay = x0+ANCHOR[0],40+ANCHOR[1]
    draw.line((ax-5,ay,ax+5,ay),fill=(240,40,130,255),width=1)
    draw.line((ax,ay-5,ax,ay+5),fill=(240,40,130,255),width=1)
comparison.convert('RGB').save(HERE/'comparison_same_scale.png')
print(json.dumps({k:{j:v for j,v in m.items() if j in ['canvas_px','alpha_bbox_gt8_xyxy_exclusive','bbox_delta_from_guide_px','transparent_fraction','border_pixels_alpha_gt8','long_edge_slope_median','corresponding_canopy_edge']} for k,m in metrics.items() if not k.startswith('_')},indent=2))
