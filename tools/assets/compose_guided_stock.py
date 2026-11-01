"""Products-only correction PoC. Original FULL and approved EMPTY remain unchanged."""
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

P=Path(__file__).resolve().parents[2]/'assets/review/guided_assets/shelf_general_open_r0_v1'
empty=np.array(Image.open(P/'empty_corrected.png').convert('RGBA'))
products_only=(P/'products_only_original.png').exists()
source=np.array(Image.open(P/('products_only_original.png' if products_only else 'full_source_original.png')).convert('RGBA'))
if products_only:
    original_size=Image.open(P/'full_source_original.png').size
    if (source.shape[1],source.shape[0])!=original_size:
        raise SystemExit('Products-only canvas changed: register row coordinates before compositing; no automatic stretch allowed')
g=json.loads((P/'guide.json').read_text(encoding='utf-8'))
ax,ay=g['anchor_px']; vectors=np.array(g['source_axis_vectors'])
project=lambda p:np.array([ax,ay])+np.array(p)@vectors
product_layers=[]; transforms=[]
# Measured FULL front rails, ordered top to bottom. Product regions only may be warped.
measurements=[(472,1055,870),(490,1074,1025),(495,1093,1185),(503,1102,1340)]
row_masks=[]
if products_only:
    _,labels,stats,_=cv2.connectedComponentsWithStats((source[:,:,3]>128).astype('uint8'),8)
    ids=sorted([i for i in range(1,len(stats)) if stats[i,4]>1000],key=lambda i:stats[i,1])
    yy,xx=np.mgrid[:source.shape[0],:source.shape[1]]
    boundary=np.interp(xx,[297,350,450,600,750,900,1050,1196],[975,984,1003,946,879,819,755,707])
    row_masks=[labels==ids[0],labels==ids[1],(labels==ids[2])&(yy<boundary),(labels==ids[2])&(yy>=boundary)]
for top_row,(left,right,intercept) in enumerate(measurements):
    row=3-top_row
    part=next(p for p in g['parts'] if p['name']==f'price_rail_{row}')
    x0,y0,z0,x1,y1,z1=part['bounds_m']
    start=project([x1,y1,z1+.006]); end=project([x1,y0,z1+.006])
    src=np.float32([[left,intercept-.5*left-12],[right,intercept-.5*right-12],
                    [left,intercept-.5*left-140]])
    dst=np.float32([start,end,start+[0,-44]])
    matrix=cv2.getAffineTransform(src,dst)
    yy,xx=np.mgrid[:source.shape[0],:source.shape[1]]
    above=intercept-.5*xx-yy
    region=(xx>=left-100)&(xx<=right)&(above>=12)&(above<=140)
    # Select product inks and food; retain interiors of closed package contours.
    hsv=cv2.cvtColor(source[:,:,:3],cv2.COLOR_RGB2HSV)
    foreground=(hsv[:,:,1]>36)&(hsv[:,:,2]>35)&region&(source[:,:,3]>128)
    if products_only:
        foreground=row_masks[top_row]
        # Fit each merchandise row's lower envelope, independent of the redrawn fixture.
        ys,xs=np.nonzero(foreground)
        low,high=int(xs.min()),int(xs.max())
        samples=[]
        for x in range(low+20,high-20,15):
            values=ys[(xs>=x-5)&(xs<=x+5)]
            if len(values)>10: samples.append([x,float(np.quantile(values,.97))])
        samples=np.array(samples); slope,b=np.polyfit(samples[:,0],samples[:,1],1)
        above_line=slope*xs+b-ys
        extent=max(1,float(np.quantile(above_line,.995)))
        src=np.float32([[low,slope*low+b],[high,slope*high+b],[low,slope*low+b-extent]])
        matrix=cv2.getAffineTransform(src,np.float32([start,end,start+[0,-44]]))
    fg=cv2.morphologyEx(foreground.astype('uint8'),cv2.MORPH_CLOSE,np.ones((3,3),np.uint8))
    contours,_=cv2.findContours(fg,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)
    mask=np.zeros_like(fg)
    for contour in contours:
        if cv2.contourArea(contour)>100: cv2.drawContours(mask,[contour],-1,255,-1)
    layer=source.copy(); layer[:,:,3]=np.minimum(layer[:,:,3],mask)
    warped=cv2.warpAffine(layer,matrix,(640,640),flags=cv2.INTER_AREA)
    warped[warped[:,:,3]==0,:3]=0
    Image.fromarray(warped).save(P/f'products_row{row}.png')
    product_layers.append(warped)
    transforms.append({'row':row,'source_front_rail':[left,right,intercept],
                       'affine_products_only':matrix.tolist(),'target_front':[start.tolist(),end.tolist()]})

# Protect the original visible upright, rail, and plinth pixels.
rgb=empty[:,:,:3].astype(float)
teal=(rgb[:,:,1]>rgb[:,:,0]*1.25)&(rgb[:,:,2]>rgb[:,:,0]*1.25)&(empty[:,:,3]>=128)
protect=cv2.dilate(teal.astype('uint8'),np.ones((3,3),np.uint8)).astype(bool)
for part in g['parts']:
    if part['name'] not in ('independent_base','upright'): continue
    # Far upright is behind merchandise: do not restore its hidden projection over products.
    if part['name']=='upright' and part['bounds_m'][1]<0: continue
    pts=np.float32(part['vertices_px']); hull=cv2.convexHull(pts).astype('int32')
    m=np.zeros((640,640),np.uint8); cv2.fillConvexPoly(m,hull,1)
    visible=m.astype(bool)&(empty[:,:,3]>=128)
    if part['name']=='independent_base':
        # A projected box hull contains hidden top faces. Restore only visible dark base pixels.
        visible&=(rgb[:,:,0]<160)&(rgb[:,:,1]<180)&(rgb[:,:,2]<190)
    protect|=visible
composite=Image.fromarray(empty)
for layer in product_layers: composite=Image.alpha_composite(composite,Image.fromarray(layer))
result=np.array(composite); result[protect]=empty[protect]
Image.fromarray(result).save(P/'full_composite_candidate.png')
Image.fromarray((protect*255).astype('uint8')).save(P/'protected_structure_mask.png')
sheet=Image.new('RGBA',(1280,680),(220,225,225,255))
sheet.alpha_composite(Image.fromarray(empty),(0,30)); sheet.alpha_composite(Image.fromarray(result),(640,30))
draw=ImageDraw.Draw(sheet); draw.text((20,10),'APPROVED EMPTY SHAPE',fill='black'); draw.text((660,10),'PRODUCTS-ONLY COMPOSITE / REVIEW',fill='black')
sheet.convert('RGB').save(P/'states_composite_comparison.png')
report={'runtime_approved':False,'method':'product-row extraction and local affine mapping onto unchanged EMPTY',
        'products_only_source':products_only,
        'protected_structure_changed_pixels':int(np.any(result[protect]!=empty[protect],axis=1).sum()),
        'transforms':transforms,'status':'review_only','limitations':['segmentation may omit pale packaging','manual product region coordinates','occlusion and product completeness require visual QA']}
(P/'composite_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(report['protected_structure_changed_pixels'],'protected pixels changed')
