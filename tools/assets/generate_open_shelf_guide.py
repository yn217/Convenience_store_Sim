"""Issue #171 r0 PoC: directly project primitive vertices using runtime constants."""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw
from blueprints import ROW_HEIGHTS

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/review/guided_assets/shelf_general_open_r0_v1'
OUT.mkdir(parents=True,exist_ok=True)
catalog=ROOT/'data/fixtures/mvp_v1.json'
projection=ROOT/'scripts/presentation/iso_projection.gd'
d=next(x for x in json.loads(catalog.read_text(encoding='utf-8')) if x['type_id']=='shelf_general')
text=projection.read_text(encoding='utf-8')
constant=lambda name:float(re.search(r'const '+name+r' := ([0-9.]+)',text)[1])
scale=constant('SOURCE_SCALE')
X,Y,Z=[constant(n)*scale for n in ('HALF_TILE_W','HALF_TILE_H','Z_PX_PER_M')]
anchor=(380,430); size=(640,640)
def project(p):
    x,y,z=p
    return [anchor[0]+X*(x-y),anchor[1]+Y*(x+y)-Z*z]

width,depth,height=[d['dimensions_m'][k] for k in ('width','depth','height')]
y0=.5-depth/2; y1=.5+depth/2; x0=-width/2; x1=width/2
parts=[]
def box(name,bounds,color): parts.append((name,bounds,color))
box('independent_base',(x0,y0,0,x1,y1,.10),(90,110,122))
box('back_panel',(-.04,y0,.10,-.02,y1,height),(218,225,225))
for yy in (y0,y1-.03): box('upright',(-.05,yy,.10,0,yy+.03,height),(112,150,172))
rows=ROW_HEIGHTS['shelf_general']; assert len(rows)==len(d['shelf_slots'])==4
for i,z in enumerate(rows):
    box(f'sales_board_{i}',(-.02,y0,z-.018,x1,y1,z),(190,211,207))
    box(f'price_rail_{i}',(x1-.015,y0,z-.035,x1,y1,z-.006),(35,122,125))

structure=Image.new('RGBA',size); edges=Image.new('RGBA',size)
faces=[]; records=[]
for name,b,c in parts:
    a,k,z,u,v,w=b
    vertices=[(xx,yy,zz) for xx in (a,u) for yy in (k,v) for zz in (z,w)]
    records.append({'name':name,'bounds_m':b,'vertices_world':vertices,'vertices_px':[project(p) for p in vertices]})
    for indices,tone in (([1,5,7,3],1.10),([4,6,7,5],.9),([2,3,7,6],.78)):
        pts=[vertices[i] for i in indices]
        distance=sum(p[0]+p[1]+p[2]*.5 for p in pts)/4
        faces.append((distance,[project(p) for p in pts],tuple(min(255,int(t*tone)) for t in c)+(255,)))
for _,points,c in sorted(faces,key=lambda f:f[0]):
    ImageDraw.Draw(structure).polygon(points,fill=c)
    ImageDraw.Draw(edges).line(points+[points[0]],fill=(25,45,55,255),width=1)
structure.save(OUT/'guide_structure.png'); edges.save(OUT/'guide_edges.png')
bbox=structure.copy(); draw=ImageDraw.Draw(bbox)
foot=[(x,y,0) for x,y in ((-.5,-.5),(.5,-.5),(.5,1.5),(-.5,1.5))]
draw.line([tuple(project(p)) for p in foot+[foot[0]]],fill=(230,90,30),width=2)
draw.ellipse((anchor[0]-4,anchor[1]-4,anchor[0]+4,anchor[1]+4),fill='red')
bbox.save(OUT/'guide_bbox.png')
mask=Image.new('RGBA',size,(0,0,0,255)); md=ImageDraw.Draw(mask)
for i,z in enumerate(rows):
    top=min(z+.25,height-.02)
    md.polygon([tuple(project(p)) for p in ((x1,y0,z),(x1,y1,z),(x1,y1,top),(x1,y0,top))],fill=(0,180,0,255))
mask.paste((220,0,0,255),(0,0,*size),structure.getchannel('A'))
mask.save(OUT/'guide_mask.png')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
info={'asset_id':'shelf_general_open_r0_v1','geometry_version':'open_shallow_guide_v1','runtime_approved':False,
      'production_method':'direct 2D projection of primitive vertices; not a Godot render',
      'catalog':str(catalog.relative_to(ROOT)),'catalog_sha256':sha(catalog),'projection_sha256':sha(projection),
      'canvas_px':size,'anchor_px':anchor,'rotation':0,'footprint':d['footprint'],'dimensions_m':d['dimensions_m'],
      'sales_face':d['access_edges'],'source_axis_vectors':[[X,Y],[-X,Y],[0,-Z]],'parts':records,
      'sales_board_count':len(rows),'canopy_count':0,'sales_board_depth_m':x1+.02,
      'mask_legend':{'red':'fixed structure','green':'product candidate region','black':'background forbidden'},
      'qa':{'geometry_review':'pending','godot_comparison':'pending','human_approval':'pending'},
      'files':{p.name:sha(p) for p in OUT.glob('*.png')}}
(OUT/'guide.json').write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding='utf-8')
print(OUT)
