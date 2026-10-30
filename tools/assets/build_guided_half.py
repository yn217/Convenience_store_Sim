"""Limited MEDIUM/HALF review state from identical EMPTY plus reduced product layers."""
import json
from pathlib import Path
import numpy as np
import cv2
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parents[2]/'assets/review/guided_assets/shelf_general_open_r0_v1'
empty=np.array(Image.open(P/'empty_corrected.png').convert('RGBA'))
protect=np.array(Image.open(P/'protected_structure_mask.png'))>0
half=Image.fromarray(empty); cuts=[]; allowed=np.zeros((640,640),bool)
for row in range(4):
    a=np.array(Image.open(P/f'products_row{row}.png').convert('RGBA'))
    counts=(a[:,:,3]>128).sum(axis=0)
    xs=np.where(counts>0)[0]; middle=int((xs[0]+xs[-1])/2)
    # Follow a package edge rather than slicing every package on a straight column.
    left,right=middle-23,middle+24
    rgb=a[:,:,:3].astype(float)
    edge=np.linalg.norm(np.diff(rgb,axis=1,prepend=rgb[:,:1]),axis=2)
    alpha=a[:,:,3]>8
    cost=np.where(alpha[:,left:right],12/(1+edge[:,left:right]/8),0.02)
    cost+=np.abs(np.arange(left,right)-middle)[None,:]*.008
    cumulative=cost.copy(); parent=np.zeros(cost.shape,np.int32)
    for y in range(1,640):
        for x in range(right-left):
            lo,hi=max(0,x-2),min(right-left,x+3)
            previous=cumulative[y-1,lo:hi]+np.abs(np.arange(lo,hi)-x)*.10
            best=lo+int(np.argmin(previous)); parent[y,x]=best
            cumulative[y,x]+=previous[best-lo]
    seam=np.zeros(640,np.int32); seam[-1]=int(np.argmin(cumulative[-1]))
    for y in range(639,0,-1): seam[y-1]=parent[y,seam[y]]
    seam+=left
    for y,cut in enumerate(seam):
        if row%2: a[y,:cut]=0
        else: a[y,cut:]=0
    allowed|=a[:,:,3]>0
    half=Image.alpha_composite(half,Image.fromarray(a))
    cuts.append({'row':row,'seam_x_min':int(seam.min()),'seam_x_max':int(seam.max()),'method':'gradient-following package separator; visual QA required'})
out=np.array(half); out[protect]=empty[protect]
Image.fromarray(out).save(P/'half_composite_candidate.png')
report={'runtime_approved':False,'stock_state':'MEDIUM','display_name':'HALF limited trial','protected_changed_pixels':int(np.any(out[protect]!=empty[protect],axis=1).sum()),
        'outside_product_support_changed_pixels':int(np.any(out[~allowed]!=empty[~allowed],axis=1).sum()),'cuts':cuts,'status':'review_only'}
(P/'half_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
sheet=Image.new('RGBA',(1920,680),(220,225,225,255))
for i,(name,label) in enumerate([('empty_corrected.png','EMPTY'),('half_composite_candidate.png','HALF / MEDIUM trial'),('full_composite_candidate.png','FULL')]):
    sheet.alpha_composite(Image.open(P/name).convert('RGBA'),(i*640,30))
    ImageDraw.Draw(sheet).text((i*640+20,10),label,fill='black')
sheet.convert('RGB').save(P/'three_states_comparison.png')
print(json.dumps(report))
