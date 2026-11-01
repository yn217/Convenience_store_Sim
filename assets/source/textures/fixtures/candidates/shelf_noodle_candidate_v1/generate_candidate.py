import hashlib,json
from pathlib import Path
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parent; W,H=442,481; C=(285,334)
def P(x,y,z=0): return (C[0]+128*(x-y),C[1]+64*(x+y)-156.76734354*z)
def poly(d,pts,fill,ol=(43,49,53,255),w=1):
 d.polygon(pts,fill=fill); d.line(pts+[pts[0]],fill=ol,width=w,joint='curve')
def shadow(r):
 im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im)
 if r in (0,2): q=[P(-.46,-.46),P(.46,-.46),P(.46,1.46),P(-.46,1.46)]
 else:q=[P(-.46,-.46),P(1.46,-.46),P(1.46,.46),P(-.46,.46)]
 poly(d,[(sum(x for x,y in q)/4+(x-sum(x for x,y in q)/4)*.96,sum(y for x,y in q)/4+8+(y-sum(y for x,y in q)/4)*.96) for x,y in q],(32,24,18,52),None)
 return im
def body(r):
 im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im); a,b=(-.46,.46) if r in (0,2) else (-.46,1.46); y0,y1=(-.46,1.46) if r in (0,2) else (-.46,.46)
 for z in [.1,.5,.9,1.3,1.66]:
  q=[P(a,y0,z),P(b,y0,z),P(b,y1,z),P(a,y1,z)]; poly(d,q,(116,124,128,255)); poly(d,[q[0],q[1],(q[1][0],q[1][1]+6),(q[0][0],q[0][1]+6)],(180,143,86,255))
 for x,y in [(a,y0),(b,y0),(b,y1),(a,y1)]: d.line([P(x,y,.08),P(x,y,1.7)],fill=(43,49,53,255),width=7)
 for row,z in enumerate([.25,.65,1.05,1.43]):
  for i in range(8):
   t=(i+.5)/8; x,y=(b-.1,y0+1.92*t) if r in (0,2) else (a+1.92*t,y1-.1); cx,cy=P(x,y,z)
   if r in (1,3): cx=570-cx
   col=(205+(i*7)%35,151+row*8,59+(i*5)%25,255); d.rounded_rectangle((cx-11,cy-15,cx+11,cy+15),3,fill=col,outline=(92,62,35,255),width=2)
 return im
def main():
 rot={}
 for r in range(4):
  bn=f'shelf_noodle_candidate_v1_{r}_body.png'; sn=f'shelf_noodle_candidate_v1_{r}_shadow.png'; body(r).save(R/bn,compress_level=9); shadow(r).save(R/sn,compress_level=9)
  rot[str(r)]={'canvas_px':[W,H],'anchor_px':[285.0 if r in (0,2) else 157.0,334.0],'layers':{'body':bn,'shadow':sn},'slot_anchors_px':{},'selection_polygon_px':([[285,270],[413,334],[157,462],[29,398]] if r in (0,2) else [[157,270],[413,398],[285,462],[29,334]]),'sorting_anchor_px':[285.0 if r in (0,2) else 157.0,334.0]}
  for row,z in enumerate([1.43,1.05,.65,.25]):
   for i in range(8):
    t=(i+.5)/8; x,y=((.46-.1,-.46+1.92*t) if r in (0,2) else (-.46+1.92*t,.46-.1)); px,py=P(x,y,z); rot[str(r)]['slot_anchors_px'][f'row{row}_item{i}']=[round(570-px if r in (1,3) else px,2),round(py,2)]
 v={'manifest_version':1,'visual_id':'shelf_noodle_candidate_v1','fixture_type_id':'shelf_noodle','projection_id':'iso2x_v1','world_units_per_tile':1,'source_px_per_tile_diamond':[256,128],'footprint':{'w':1,'h':2},'dimensions_m':{'width':.92,'depth':1.92,'height':1.7},'rotations':rot}
 (R/'shelf_noodle_candidate_v1.visual.json').write_text(json.dumps(v,indent=2)+'\n')
 (R/'REVIEW_ONLY.json').write_text(json.dumps({'review_only':True,'runtime_approved':False,'generator':'deterministic_pillow_fallback','access_edge':'E','shelf_height_m':1.7,'unverified_points':['Blender projection calibration not verified.','Material fidelity and slot readability need human review.','Godot integration intentionally not run.'],'files':{'visual_manifest':'shelf_noodle_candidate_v1.visual.json','regeneration_script':'generate_candidate.py'}},indent=2)+'\n')
 h={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(R.iterdir()) if p.is_file() and p.name!='SHA256SUMS.json'}; (R/'SHA256SUMS.json').write_text(json.dumps(h,indent=2)+'\n')
if __name__=='__main__': main()
