from pathlib import Path
from hashlib import sha256
import json
from PIL import Image, ImageDraw

ROOT=Path(__file__).parent; S=(512,512); A=(256,438); Z=156.76734354
def iso(x,y,z=0): return (A[0]+128*(x-y), A[1]+64*(x+y)-Z*z)
def render(r):
    b=Image.new('RGBA',S,(0,0,0,0)); s=Image.new('RGBA',S,(0,0,0,0)); d=ImageDraw.Draw(b); q=ImageDraw.Draw(s)
    fp=[(0,0,0),(0,2,0),(1,2,0),(1,0,0)] if r in (0,2) else [(0,0,0),(2,0,0),(2,1,0),(0,1,0)]
    q.polygon([iso(*p) for p in fp],fill=(20,16,12,82))
    def tr(x,y,z): return ((x,y,z) if r==0 else ((2-y,x,z) if r==1 else ((1-x,2-y,z) if r==2 else (y,1-x,z))))
    def P(x,y,z=0): return iso(*tr(x,y,z))
    def pg(ps,fill,outline=(45,35,25,255),width=1): d.polygon([P(*p) for p in ps],fill=fill,outline=outline,width=width)
    pg([(0.04,.04,0),(.96,.04,0),(.96,1.96,0),(.04,1.96,0)],(95,72,49,255),width=2)
    pg([(0.04,.04,1.6),(.96,.04,1.6),(.96,1.96,1.6),(.04,1.96,1.6)],(151,116,75,255),width=2)
    for z in (.36,.78,1.2):
        pg([(0.04,.06,z),(.96,.06,z),(.96,1.94,z),(.04,1.94,z)],(115,82,48,255))
        for y in (.28,.72,1.16,1.6): pg([(.54,y,z+.015),(.88,y,z+.015),(.88,y+.2,z+.015),(.54,y+.2,z+.015)],(214,151,45,255),None,1)
    pg([(.94,.06,.04),(.98,.06,.04),(.98,1.94,.04),(.94,1.94,.04)],(40,170,190,255),None,1)
    return b,s

rot={}
for r in range(4):
    b,s=render(r); bn=f'shelf_snack_{r}_body.png'; sn=f'shelf_snack_{r}_shadow.png'; b.save(ROOT/bn,optimize=False,compress_level=9); s.save(ROOT/sn,optimize=False,compress_level=9)
    rot[str(r)]={'canvas_px':list(S),'anchor_px':list(A),'layers':{'body':bn,'shadow':sn},'slot_anchors_px':{f'row{a}_item{i}':[float(120+i*35),float(220+a*45)] for a in range(3) for i in range(6)},'selection_polygon_px':[[104,438],[256,486],[408,438],[256,390]],'sorting_anchor_px':list(A)}
manifest={'manifest_version':1,'visual_id':'shelf_snack_candidate_v1','fixture_type_id':'shelf_snack','projection_id':'iso2x_v1','world_units_per_tile':1,'source_px_per_tile_diamond':[256,128],'footprint':{'w':1,'h':2},'dimensions_m':{'width':.92,'depth':1.92,'height':1.6},'rotations':rot}
(ROOT/'visual_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
pngs=sorted(ROOT.glob('*.png'))
review={'runtime_approved':False,'generator':'Pillow deterministic fallback','projection_id':'iso2x_v1','source_px_per_tile':[256,128],'access_edge':'E','shelf_height_m':1.6,'physical_dimensions_m':[.92,1.92,1.6],'unverified_points':['Blender camera calibration and projection tolerance not verified.','Visual silhouette and slot readability review is pending.','Godot runtime integration intentionally not performed.'],'sha256':{p.name:sha256(p.read_bytes()).hexdigest() for p in pngs},'files':[p.name for p in pngs]}
(ROOT/'review_manifest.json').write_text(json.dumps(review,indent=2)+'\n',encoding='utf-8')
