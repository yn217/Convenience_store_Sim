"""Build the required light-background v2b review board at 1x and 0.3x."""
import json
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]; BASE=ROOT/'assets/generated/characters'; OUT=ROOT/'docs/art/characters_v2b_contact.png'
VARIANTS=['office_worker','student_uniform','casual_woman','casual_man','older_person','parent','clerk']
KEYS=[('walk',0),('walk',3),('idle',0),('inspect',0)]
CELL_W,CELL_H=190,155; GAP=8; LABEL=22
def board(scale):
    width=LABEL+4*(CELL_W*scale+GAP); height=LABEL+len(VARIANTS)*(CELL_H*scale+GAP)
    im=Image.new('RGB',(int(width),int(height)),(247,245,238)); d=ImageDraw.Draw(im)
    for row,vid in enumerate(VARIANTS):
        y=LABEL+row*(CELL_H*scale+GAP); d.text((4,y+4),vid,fill=(30,40,48))
        m=json.loads((BASE/vid/f'{vid}.character.json').read_text(encoding='utf-8'))
        for col,(anim,frame) in enumerate(KEYS):
            anim=anim if anim in m['animations'] else 'checkout' if 'checkout' in m['animations'] else 'idle'
            frame=min(frame,m['animations'][anim]['frames']-1); x=LABEL+col*(CELL_W*scale+GAP)
            d.text((x+2,y+2),f'{anim}{frame}',fill=(45,55,60))
            for facing in range(4):
                fn=m['directions'][str(facing)][anim][frame]; spr=Image.open(BASE/vid/fn).convert('RGBA')
                spr=spr.resize((int(190*scale),int(329*scale)),Image.Resampling.LANCZOS)
                px=int(x+facing*(CELL_W/4)*scale+(CELL_W/4*scale-190*scale)/2); py=int(y+LABEL+(CELL_H-LABEL)*scale-329*scale)
                im.paste(spr,(px,py),spr)
    return im
one=board(1.0); small=board(0.3); canvas=Image.new('RGB',(max(one.width,small.width),one.height+small.height+26),(247,245,238)); d=ImageDraw.Draw(canvas); d.text((4,4),'v2b key frames — front / back / left / right; light background',fill=(20,35,45)); canvas.paste(one,(0,20)); d.text((4,one.height+21),'same board at 0.3x (game readability)',fill=(20,35,45)); canvas.paste(small,(0,one.height+40)); OUT.parent.mkdir(parents=True,exist_ok=True); canvas.save(OUT,optimize=True); print(f'wrote {OUT}')
