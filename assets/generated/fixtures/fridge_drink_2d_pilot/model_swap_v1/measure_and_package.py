"""Limited image QA and uniform whole-sprite fitting to the canonical canvas."""
from pathlib import Path
import hashlib, json, math
import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE=Path(__file__).resolve().parent
SIZE=(442,527)
ANCHOR=(285,380)

def measure(p):
    im=Image.open(p).convert('RGBA'); a=np.asarray(im)[:,:,3]
    bbox=Image.fromarray((a>8).astype('uint8')*255).getbbox()
    bg=Image.new('RGBA',im.size,(64,68,73,255)); bg.alpha_composite(im)
    gray=cv2.cvtColor(np.asarray(bg)[:,:,:3],cv2.COLOR_RGB2GRAY)
    lines=cv2.HoughLinesP(cv2.Canny(gray,60,160),1,np.pi/180,48,minLineLength=im.width*.25,maxLineGap=10)
    slopes=[]
    for x1,y1,x2,y2 in ([] if lines is None else lines[:,0]):
        if x1!=x2:
            s=(y2-y1)/(x2-x1)
            if -.7<s<-.3: slopes.append(float(s))
    border=np.concatenate([a[0],a[-1],a[:,0],a[:,-1]])
    return {'canvas_px':list(im.size),'alpha_bbox_gt8_xyxy_exclusive':list(bbox),
      'transparent_fraction':float(np.mean(a==0)),'partial_alpha_fraction':float(np.mean((a>0)&(a<255))),
      'border_pixels_alpha_gt8':int(np.sum(border>8)),
      'long_diagonal_slope_median':float(np.median(slopes)) if slopes else None,
      'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}

inputs=[HERE/'input_guide.png']
metrics={}
transform={}
for variant in ['a','b']:
    src=HERE/f'original_{variant}.png'; im=Image.open(src).convert('RGBA')
    scale=min(SIZE[0]/im.width,SIZE[1]/im.height)
    dims=(round(im.width*scale),round(im.height*scale)); offset=((SIZE[0]-dims[0])//2,(SIZE[1]-dims[1])//2)
    outim=Image.new('RGBA',SIZE)
    outim.paste(im.resize(dims,Image.Resampling.LANCZOS),offset)
    out=HERE/f'fridge_drink_full_r0_candidate_{variant}.png'; outim.save(out); inputs.append(out)
    transform[variant]={'source_canvas_px':list(im.size),'uniform_scale':scale,'resized_px':list(dims),'transparent_offset_px':list(offset),'operation':'whole image uniform resampling and transparent canvas placement only','anchor_px':ANCHOR}
for p in inputs: metrics[p.name]=measure(p)
ref=metrics['input_guide.png']['alpha_bbox_gt8_xyxy_exclusive']
for p in inputs[1:]:
    m=metrics[p.name]; b=m['alpha_bbox_gt8_xyxy_exclusive']
    m['bbox_delta_from_guide_px']=[x-y for x,y in zip(b,ref)]
    m['bbox_aspect_ratio_vs_guide']=(b[2]-b[0])/(b[3]-b[1])/((ref[2]-ref[0])/(ref[3]-ref[1]))
    m['anchor_px']=ANCHOR
    m['long_diagonal_target_slope']=-.5
    m['slope_tolerance_diagnostic']={'interval':[-.54,-.46],'pass':m['long_diagonal_slope_median'] is not None and -.54<=m['long_diagonal_slope_median']<=-.46}
for v in ['a','b']: metrics[f'original_{v}.png']=measure(HERE/f'original_{v}.png')
metrics['_normalization']=transform
metrics['_method']='Alpha >8 bbox, border transparency, Canny 60/160 + Hough long negative diagonals. Slope is a diagnostic only and does not prove exact geometry. Final candidates are complete original sprites scaled uniformly to fit 442x527 with transparent padding; comparison displays 1:1 canvases.'
(HERE/'qa_metrics.json').write_text(json.dumps(metrics,indent=2),encoding='utf-8')
comp=Image.new('RGBA',(3*466,583),(38,41,46,255)); draw=ImageDraw.Draw(comp)
for i,p in enumerate(inputs):
    x0=i*466+12; draw.text((x0,12),['GUIDE 442x527','A FULL/r0 442x527','B FULL/r0 442x527'][i],fill='white')
    for y in range(40,567,12):
        for x in range(x0,x0+442,12):
            c=215 if ((x-x0)//12+(y-40)//12)%2 else 238
            draw.rectangle((x,y,min(x+11,x0+441),min(y+11,566)),fill=(c,c,c,255))
    comp.alpha_composite(Image.open(p).convert('RGBA'),(x0,40))
    ax,ay=x0+ANCHOR[0],40+ANCHOR[1]
    draw.line((ax-5,ay,ax+5,ay),fill=(242,38,136,255)); draw.line((ax,ay-5,ax,ay+5),fill=(242,38,136,255))
comp.convert('RGB').save(HERE/'comparison_same_scale.png')
print(json.dumps({k:{f:m.get(f) for f in ['canvas_px','alpha_bbox_gt8_xyxy_exclusive','bbox_delta_from_guide_px','bbox_aspect_ratio_vs_guide','transparent_fraction','border_pixels_alpha_gt8','long_diagonal_slope_median','slope_tolerance_diagnostic']} for k,m in metrics.items() if not k.startswith('_')},indent=2))
