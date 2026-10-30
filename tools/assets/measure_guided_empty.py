"""Diagnostic rail-line and alpha measurements; does not approve the candidate."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

P=Path(__file__).resolve().parents[2]/'assets/review/guided_assets/shelf_general_open_r0_v1'
g=json.loads((P/'guide.json').read_text(encoding='utf-8'))
im=np.array(Image.open(P/'empty_corrected.png').convert('RGBA')).astype(float)
rgb=im[:,:,:3]; alpha=im[:,:,3]
teal=(rgb[:,:,1]>rgb[:,:,0]*1.25)&(rgb[:,:,2]>rgb[:,:,0]*1.25)&(alpha>=128)
ax,ay=g['anchor_px']; vectors=np.array(g['source_axis_vectors'])
project=lambda p:np.array([ax,ay])+np.array(p)@vectors
rails=[]
for part in g['parts']:
    if not part['name'].startswith('price_rail'): continue
    x0,y0,z0,x1,y1,z1=part['bounds_m']
    start,end=project([x1,y0,(z0+z1)/2]),project([x1,y1,(z0+z1)/2])
    found=[]; residuals=[]
    for t in np.linspace(.05,.95,80):
        p=start*(1-t)+end*t; x=int(round(p[0])); y=int(round(p[1]))
        candidates=[yy for yy in range(max(0,y-6),min(640,y+7)) if teal[yy,x]]
        if candidates:
            yy=float(np.mean(candidates)); found.append([x,yy]); residuals.append(yy-p[1])
    if len(found)>2:
        points=np.array(found); slope,intercept=np.polyfit(points[:,0],points[:,1],1)
        rails.append({'part':part['name'],'samples':len(found),'expected_slope':-.5,
                      'observed_slope':float(slope),'median_vertical_offset_px':float(np.median(residuals)),
                      'max_abs_vertical_offset_px':float(np.max(np.abs(residuals)))})
boxes={}
for threshold in (1,8,128):
    yy,xx=np.nonzero(alpha>=threshold)
    box=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
    boxes[str(threshold)]={'bbox':box,'margins_px':[box[0],box[1],640-box[2],640-box[3]],
                          'all_margins_at_least_12_percent':min(box[0],box[1],640-box[2],640-box[3])>=76.8}
report={'runtime_approved':False,'alpha':boxes,'rail_diagnostics':rails,
        'scope':'Color-based rail-line diagnostic only. Corners, upright positions, ground anchor and human shape approval remain separate.',
        'status':'review_only'}
(P/'image_measurements.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
