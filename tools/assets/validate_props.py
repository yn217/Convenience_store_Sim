"""Contract checks for generated prop sprites (Issue #103)."""
import json, sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]; BASE=ROOT/'assets/generated/props'
def main():
    errors=[]; count=0
    for folder in sorted(BASE.iterdir()):
        if not folder.is_dir(): continue
        ms=list(folder.glob('*.visual.json'))
        if len(ms)!=1: errors.append(f'{folder.name}: exactly one visual manifest required'); continue
        m=json.loads(ms[0].read_text(encoding='utf-8')); count+=1
        if m.get('projection_id')!='iso2x_v1' or set(m.get('rotations',{})) != {'0','1','2','3'}: errors.append(f'{folder.name}: projection/rotations')
        if not (folder/'PROVENANCE.json').is_file(): errors.append(f'{folder.name}: PROVENANCE.json missing')
        for r, spec in m.get('rotations',{}).items():
            if spec.get('canvas_px') != [320,320] or 'body' not in spec.get('layers',{}): errors.append(f'{folder.name} r{r}: canvas/layer')
            f=folder/spec['layers']['body']
            if not f.is_file(): errors.append(f'{folder.name} r{r}: png missing'); continue
            im=Image.open(f)
            if im.mode!='RGBA' or im.size!=(320,320): errors.append(f'{folder.name} r{r}: RGBA 320x320 required')
            if im.getbbox() is None: errors.append(f'{folder.name} r{r}: empty sprite')
    print(f'props check: {count} manifest(s), {len(errors)} problem(s)')
    for e in errors: print('PROPS:',e)
    return bool(errors)
if __name__=='__main__': sys.exit(main())
