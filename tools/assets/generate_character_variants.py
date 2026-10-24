"""Deterministic connected character sprites for issue #104."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/generated/characters'
FACINGS=('E','S','W','N')
CUSTOMERS={
 'office_worker':(1.70,(42,73,116),(34,39,54),(28,24,30),(224,178,146),(45,32,24),'briefcase'),
 'student_uniform':(1.58,(52,84,136),(44,48,70),(38,26,22),(235,190,165),(185,150,48),'backpack'),
 'casual_woman':(1.62,(210,92,126),(74,76,94),(72,38,46),(238,190,170),(54,31,29),'tote'),
 'casual_man':(1.68,(45,145,125),(72,78,84),(45,30,20),(220,170,140),(30,66,55),'basket'),
 'older_person':(1.60,(112,143,172),(78,82,92),(150,150,145),(205,155,125),(90,65,55),'cane'),
 'parent':(1.66,(216,145,62),(52,72,90),(55,35,25),(232,184,160),(45,35,30),'basket'),
}
CLERK={'clerk':(1.65,(32,112,130),(34,48,64),(25,22,20),(225,180,150),(240,205,88),'name_tag')}

def poly(d,pts,c): d.polygon(pts,fill=(*c,255))

def sprite(spec,facing,anim,frame,w=190,h=329):
    height,shirt,pants,hair,skin,accent,carry=spec; im=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(im)
    anchor=282; top=round(anchor-height*156.767); total=anchor-top
    head_h=round(total*0.14); head_w=22 if facing in (0,1) else 14
    cx=95+(2 if facing==3 else -2 if facing==2 else 0); walk=math.sin((frame%6)/6*math.tau) if anim=='walk' else 0
    leg_y=anchor-round(total*0.43); shoulder=top+round(total*0.38); hip=leg_y+2
    d.ellipse((55,anchor-3,135,anchor+6),fill=(20,30,35,78))
    shift=round(walk*5)
    for side,off in ((-1,-10),(1,10)):
        dx=shift*side; d.rounded_rectangle((cx+off-5+dx,leg_y,cx+off+4+dx,anchor-4),2,fill=(*pants,255)); d.rounded_rectangle((cx+off-7+dx,anchor-8,cx+off+6+dx,anchor+1),2,fill=(28,28,32,255))
    torso=[(cx-13,shoulder),(cx+13,shoulder+2),(cx+10,hip),(cx-9,hip)] if facing in (2,3) else [(cx-23,shoulder),(cx+23,shoulder),(cx+18,hip),(cx-18,hip)]
    poly(d,torso,shirt); d.rectangle((cx-7,top+head_h-1,cx+7,shoulder+4),fill=(*skin,255))
    arm=round(-walk*5)
    if facing in (0,1):
        d.line((cx-21,shoulder+4,cx-22+arm,hip-1),fill=(*shirt,255),width=7); d.line((cx+21,shoulder+4,cx+22-arm,hip-1),fill=(*shirt,255),width=7)
    else: d.line((cx+(8 if facing==3 else -8),shoulder+3,cx+(11 if facing==3 else -11)+arm,hip),fill=(*shirt,255),width=7)
    if facing==0:
        d.ellipse((cx-head_w,top,cx+head_w,top+head_h+2),fill=(*skin,255)); d.pieslice((cx-head_w,top-2,cx+head_w,top+9),180,360,fill=(*hair,255)); d.rectangle((cx-8,top+2,cx+8,top+5),fill=(*hair,255)); d.ellipse((cx-7,top+7,cx-5,top+9),fill=(35,30,30,255)); d.ellipse((cx+5,top+7,cx+7,top+9),fill=(35,30,30,255))
    elif facing==1:
        d.ellipse((cx-head_w,top,cx+head_w,top+head_h+2),fill=(*hair,255)); d.rectangle((cx-head_w+2,top+7,cx+head_w-2,top+head_h+3),fill=(*hair,255))
    else:
        d.ellipse((cx-head_w,top,cx+head_w,top+head_h+2),fill=(*skin,255)); d.pieslice((cx-head_w,top-2,cx+head_w,top+9),170 if facing==2 else 190,350 if facing==2 else 10,fill=(*hair,255)); nx=cx-12 if facing==2 else cx+12; d.polygon([(nx,top+7),(nx+(-4 if facing==2 else 4),top+9),(nx,top+11)],fill=(*skin,255))
    if carry=='briefcase':
        px=cx+(25 if facing in (0,3) else -25); d.rounded_rectangle((px-8,hip-1,px+9,hip+14),2,fill=(*accent,255)); d.line((px-4,hip-2,px+5,hip-2),fill=(*accent,255),width=2)
    elif carry=='backpack' and facing in (1,2,3): d.rounded_rectangle((cx-17,shoulder+2,cx+17,hip-4),4,fill=(*accent,255))
    elif carry=='tote':
        px=cx-25 if facing in (0,2) else cx+25; d.line((px-6,hip-3,px+5,hip-18),fill=(*accent,255),width=3); d.rounded_rectangle((px-10,hip-2,px+9,hip+14),3,fill=(*accent,255))
    elif carry=='basket':
        px=cx+25 if facing in (0,3) else cx-25; d.rounded_rectangle((px-11,hip-1,px+11,hip+13),3,fill=(*accent,255)); d.arc((px-9,hip-12,px+9,hip+5),180,360,fill=(*accent,255),width=2)
    elif carry=='cane':
        px=cx+24 if facing in (0,3) else cx-24; d.line((px,shoulder+18,px,anchor+1),fill=(*accent,255),width=3); d.arc((px-6,shoulder+12,px+6,shoulder+25),180,350,fill=(*accent,255),width=2)
    elif carry=='name_tag': d.rounded_rectangle((cx+8,shoulder+8,cx+17,shoulder+15),1,fill=(*accent,255))
    return im

def make(vid,spec,clerk=False):
    anims={'idle':2,'checkout':4} if clerk else {'walk':6,'idle':2,'inspect':4}; folder=OUT/vid; folder.mkdir(parents=True,exist_ok=True); directions={str(i):{} for i in range(4)}
    for i in range(4):
        for anim,count in anims.items():
            directions[str(i)][anim]=[]
            for f in range(count):
                name=f'd{i}_{anim}_f{f}.png'; sprite(spec,i,anim,f).save(folder/name); directions[str(i)][anim].append(name)
    sh=Image.new('RGBA',(190,329),(0,0,0,0)); ImageDraw.Draw(sh).ellipse((55,279,135,288),fill=(20,30,35,85)); sh.save(folder/'shadow.png')
    m={'manifest_version':1,'visual_id':vid,'projection_id':'iso2x_v1','world_units_per_tile':1,'source_px_per_tile_diamond':[256,128],'height_m':spec[0],'facing_names':list(FACINGS),'canvas_px':[190,329],'anchor_px':[95.0,282.0],'shadow':'shadow.png','animations':{a:{'frames':n,'fps':(2/1.2 if a=='idle' else 4/.45 if a in ('inspect','checkout') else 8.0),'loop':a in ('idle','walk')} for a,n in anims.items()},'directions':directions}
    (folder/f'{vid}.character.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

for vid,spec in {**CUSTOMERS,**CLERK}.items(): make(vid,spec,vid=='clerk')
