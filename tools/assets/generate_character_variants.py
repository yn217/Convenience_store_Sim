"""Deterministic Pillow character sprite generator for issue #104.

The source design is the generated turnaround reference; runtime sprites are
procedural, license-free, and use the existing iso2x canvas/anchor contract.
"""
import json, math, shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/generated/characters'
FACINGS=('E','S','W','N')
CUSTOMERS={
 'office_worker':(1.70,(38,65,105),(38,40,50),(24,24,30),(224,177,145),(55,35,25),'briefcase'),
 'student_uniform':(1.58,(48,82,130),(45,48,68),(35,25,20),(235,190,165),(35,35,45),'backpack'),
 'casual_woman':(1.62,(224,105,130),(70,72,90),(70,35,45),(238,190,170),(55,30,25),'tote'),
 'casual_man':(1.68,(45,145,125),(75,80,85),(45,30,20),(220,170,140),(35,35,38),'basket'),
 'older_person':(1.60,(125,150,175),(80,85,95),(150,150,145),(205,155,125),(90,65,55),'bag'),
 'parent':(1.66,(220,150,65),(55,75,90),(55,35,25),(232,184,160),(45,35,30),'basket'),
}
CLERK={'clerk':(1.65,(30,105,125),(30,45,60),(25,22,20),(225,180,150),(30,55,60),None)}

def sprite(spec, facing, anim, frame, w=190,h=329):
    height,shirt,pants,hair,skin,accent,carry=spec; im=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(im)
    # direction changes are deliberately asymmetric, never image mirroring
    side=(-1,0,1,0)[facing]; sway=round(math.sin(frame*math.pi/3)*5) if anim=='walk' else 0
    cx=95+side*2; anchor=282; scale=height/1.65; top=anchor-round(156.767*height)-20
    def box(x0,y0,x1,y1,c): d.rounded_rectangle((x0,y0,x1,y1),radius=3,fill=(*c,255))
    # shadow
    d.ellipse((55,anchor-3,135,anchor+6),fill=(20,30,35,85))
    legtop=anchor-108; box(cx-22+sway,legtop,cx-5,anchor-8,pants); box(cx+5-sway,legtop,cx+22,anchor-8,pants)
    box(cx-25+sway,anchor-10,cx-2+sway,anchor+1,(24,24,28)); box(cx+2-sway,anchor-10,cx+25-sway,anchor+1,(24,24,28))
    box(cx-32,legtop-68,cx+32,legtop+4,shirt); box(cx-28,legtop-72,cx+28,legtop-65,accent)
    box(cx-18,top+28,cx+18,top+68,skin); box(cx-20,top+20,cx+20,top+38,hair)
    # facing-specific arm/prop silhouettes
    if carry:
        px=cx+(-25 if facing in (0,3) else 25); py=legtop-35
        if carry=='briefcase': box(px-18,py,px+18,py+25,accent)
        elif carry=='backpack': box(cx-42,legtop-55,cx-28,legtop-5,accent)
        elif carry=='tote': d.line((px,legtop-40,px-8,legtop-5),fill=accent,width=5); box(px-18,legtop-5,px+10,legtop+20,accent)
        elif carry=='basket': box(px-18,legtop-3,px+18,legtop+17,accent); d.arc((px-13,legtop-15,px+13,legtop+8),180,360,fill=accent,width=3)
        else: box(px-14,legtop-1,px+14,legtop+19,accent)
    # clerk badge and checkout gesture
    if anim=='checkout':
        d.line((cx+18,legtop-45,cx+48,legtop-22),fill=skin,width=7)
        box(cx+40,legtop-28,cx+57,legtop-14,(245,205,80))
    if carry is None: box(cx-15,legtop-48,cx+15,legtop-40,(220,225,225))
    return im

def make(vid,spec,clerk=False):
    anims={'idle':2,'checkout':4} if clerk else {'walk':6,'idle':2,'inspect':4}
    # fixed crop/canvas across every frame in this variant
    folder=OUT/vid; folder.mkdir(parents=True,exist_ok=True)
    directions={str(i):{} for i in range(4)}
    for i in range(4):
        for anim,n in anims.items():
            directions[str(i)][anim]=[]
            for f in range(n):
                fn=f'd{i}_{anim}_f{f}.png'; sprite(spec,i,anim,f).save(folder/fn); directions[str(i)][anim].append(fn)
    sh=Image.new('RGBA',(190,329),(0,0,0,0)); ImageDraw.Draw(sh).ellipse((55,279,135,288),fill=(20,30,35,85)); sh.save(folder/'shadow.png')
    m={'manifest_version':1,'visual_id':vid,'projection_id':'iso2x_v1','world_units_per_tile':1,'source_px_per_tile_diamond':[256,128],'height_m':spec[0],'facing_names':list(FACINGS),'canvas_px':[190,329],'anchor_px':[95.0,282.0],'shadow':'shadow.png','animations':{a:{'frames':n,'fps':(2/1.2 if a=='idle' else 4/.45 if a in ('inspect','checkout') else 8.0),'loop':a=='idle' or a=='walk'} for a,n in anims.items()},'directions':directions}
    (folder/f'{vid}.character.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

for vid,s in {**CUSTOMERS,**CLERK}.items(): make(vid,s,vid=='clerk')
