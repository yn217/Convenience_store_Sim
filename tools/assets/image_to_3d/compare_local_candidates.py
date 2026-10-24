"""Local-only comparison: separate aesthetic crops from calibrated pixel scale.

Input renders must use iso2x_v1 with the origin at the canvas centre. This script
does not identify products, infer access edges or approve geometry from pixels.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BG = (231, 237, 242, 255)
INK = (31, 49, 66)


def font(size):
    path = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
    return ImageFont.truetype(path, size)


def stamp(draw, xy, text, size=20, fill=INK):
    draw.text(xy, text, font=font(size), fill=fill)


def alpha_crop(im):
    box = im.getchannel('A').getbbox()
    if box is None:
        raise ValueError('Empty render')
    return im.crop(box), box


def inset(sheet, image, rect):
    x, y, w, h = rect
    thumb = image.copy()
    thumb.thumbnail((w, h), Image.Resampling.LANCZOS)
    sheet.alpha_composite(thumb, (x + (w-thumb.width)//2, y+(h-thumb.height)//2))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', required=True)
    p.add_argument('--procedural', required=True)
    p.add_argument('--ai', required=True)
    p.add_argument('--out', required=True)
    p.add_argument('--label', default='Hunyuan shape only / texture pending')
    args = p.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    paths = [Path(args.reference), Path(args.procedural), Path(args.ai)]
    reference, procedural, ai = [Image.open(path).convert('RGBA') for path in paths]
    sheet = Image.new('RGBA', (1800, 1120), BG)
    draw = ImageDraw.Draw(sheet)
    stamp(draw, (25, 18), 'shelf_general FULL: local Image-to-3D evaluation, NOT APPROVED', 27)
    stamp(draw, (25, 60), 'Upper: individually fitted crops (NOT a scale comparison). Reference is art direction only.', 19)
    labels = ['User reference / uncalibrated', 'Conventional Blender comparator', args.label]
    for i, (im, label) in enumerate(zip((reference, procedural, ai), labels)):
        stamp(draw, (25+i*595, 105), label, 18)
        inset(sheet, alpha_crop(im)[0], (25+i*595, 140, 565, 420))
    stamp(draw, (25, 590), 'Lower: same iso2x_v1 source pixel scale. Preview only; canonical files and anchors are unchanged.', 19)
    crops = []
    bounds = []
    for im in (procedural, ai):
        _, box = alpha_crop(im)
        cx, cy = im.width//2, im.height//2
        bounds.append((box[0]-cx, box[1]-cy, box[2]-cx, box[3]-cy))
    lo_x, lo_y = min(b[0] for b in bounds)-12, min(b[1] for b in bounds)-12
    hi_x, hi_y = max(b[2] for b in bounds)+12, max(b[3] for b in bounds)+12
    for im in (procedural, ai):
        panel = Image.new('RGBA', (hi_x-lo_x, hi_y-lo_y), (0, 0, 0, 0))
        panel.alpha_composite(im, (-lo_x-im.width//2, -lo_y-im.height//2))
        crops.append(panel)
    for i, im in enumerate(crops):
        x = 40+i*550
        stamp(draw, (x, 635), ('Procedural' if i == 0 else 'Image-to-3D')+' / source 2x', 18)
        sheet.alpha_composite(im, (x, 674))
        for zoom in (0.5, 1.0, 1.6, 2.0):
            factor = zoom/2
            scaled = im.resize((max(1, round(im.width*factor)), max(1, round(im.height*factor))), Image.Resampling.LANCZOS)
            scaled.save(out / f'{"procedural" if i == 0 else "ai"}_zoom_{zoom:g}.png')
    stamp(draw, (1190, 650), 'Game zoom 1.0 equivalent', 20)
    stamp(draw, (1190, 682), '(not a Godot screenshot)', 18)
    for i, im in enumerate(crops):
        small = im.resize((round(im.width*.5), round(im.height*.5)), Image.Resampling.LANCZOS)
        sheet.alpha_composite(small, (1190+i*275, 735))
    stamp(draw, (1190, 1010), 'Product/front/shelf exposure: UNKNOWN', 17, (153, 40, 30))
    stamp(draw, (1190, 1040), 'Fused mesh: no semantic masks available.', 17)
    sheet.convert('RGB').save(out/'comparison.png')
    report = {
        'runtime_approved': False,
        'distribution': 'LOCAL EVALUATION ONLY',
        'inputs': [{'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in paths],
        'lower_scale': 'unchanged source pixels, iso2x_v1 assumed from render metadata',
        'canonical_assets_modified': False,
        'game_scale_preview': 'downsampled source render, NOT actual Godot screenshot',
        'semantic_measurements': {'product_front_area_px': 'UNKNOWN', 'shelf_exposure_px': 'UNKNOWN', 'category_readability': 'INDEPENDENT_REVIEW_REQUIRED'},
        'ai_label': args.label,
    }
    (out/'comparison.json').write_text(json.dumps(report, indent=2)+'\n')


if __name__ == '__main__':
    main()
