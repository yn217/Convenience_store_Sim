"""Issue #171: component cleanup and uniform translation/scale, preserving original PNG."""
import hashlib
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
P=ROOT/'assets/review/guided_assets/shelf_general_open_r0_v1'
source=Image.open(P/'source_original.png').convert('RGBA')
guide=Image.open(P/'guide_structure.png').convert('RGBA')
a=np.array(source)
count,labels,stats,_=cv2.connectedComponentsWithStats((a[:,:,3]>=8).astype('uint8'),8)
component=1+np.argmax(stats[1:,cv2.CC_STAT_AREA])
keep=labels==component
# Retain feathering immediately around the main component; discard distant alpha speckles.
keep=cv2.dilate(keep.astype('uint8'),np.ones((3,3),np.uint8)).astype(bool)
a[~keep]=0
clean=Image.fromarray(a)
clean.save(P/'cleaned_original_size.png')
def bbox(alpha):
    yy,xx=np.nonzero(alpha>=128)
    return (int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
sb=bbox(a[:,:,3]); gb=bbox(np.array(guide)[:,:,3])
sw,sh=sb[2]-sb[0],sb[3]-sb[1]; gw,gh=gb[2]-gb[0],gb[3]-gb[1]
scale=min(gw/sw,gh/sh)
tx=(gb[0]+gb[2])/2-scale*(sb[0]+sb[2])/2
ty=gb[3]-scale*sb[3]
corrected=clean.transform(guide.size,Image.Transform.AFFINE,(1/scale,0,-tx/scale,0,1/scale,-ty/scale),Image.Resampling.BICUBIC)
corrected.save(P/'empty_corrected.png')
ga=np.array(guide)[:,:,3]>=128; ca=np.array(corrected)[:,:,3]>=128
iou=float(np.logical_and(ga,ca).sum()/np.logical_or(ga,ca).sum())
outline=ga & ~cv2.erode(ga.astype('uint8'),np.ones((3,3),np.uint8)).astype(bool)
overlay=corrected.copy(); o=np.array(overlay); o[outline]=(255,70,50,255)
Image.fromarray(o).save(P/'guide_edge_overlay.png')
sheet=Image.new('RGBA',(1280,680),(220,225,225,255))
sheet.alpha_composite(guide,(0,30)); sheet.alpha_composite(corrected,(640,30))
draw=ImageDraw.Draw(sheet); draw.text((20,10),'GEOMETRY GUIDE',fill='black'); draw.text((660,10),'IMAGEGEN + UNIFORM CORRECTION / REVIEW ONLY',fill='black')
sheet.convert('RGB').save(P/'comparison.png')
report={'runtime_approved':False,'source_sha256':hashlib.sha256((P/'source_original.png').read_bytes()).hexdigest(),
        'source_bbox_alpha128':sb,'guide_bbox_alpha128':gb,'uniform_scale':scale,'translation_px':[tx,ty],
        'nonuniform_stretch':False,'mirror':False,'corrected_bbox_alpha128':bbox(np.array(corrected)[:,:,3]),
        'silhouette_iou_reference_only':iou,'canvas_px':guide.size,
        'anchor_px':json.loads((P/'guide.json').read_text(encoding='utf-8'))['anchor_px'],
        'status':'review_only','control_point_match':'not yet measured; silhouette IoU is not approval',
        'cleaning':'largest alpha>=8 component plus 1px feather neighborhood; original preserved'}
(P/'correction_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
