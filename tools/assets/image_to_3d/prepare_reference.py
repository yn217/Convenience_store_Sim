"""Extract the shelf hero from the supplied design sheet; save audit metadata.

The hand-traced silhouette and annotation masks are specific to this reference.
They do not define any game geometry or dimensions.
"""
import argparse
import hashlib
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', required=True)
    p.add_argument('--out', required=True)
    args = p.parse_args()
    source, out = Path(args.source), Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    im = Image.open(source).convert('RGB')
    if im.size != (1448, 1086):
        # Sheet was supplied at 1448 px wide; preserve proportional coordinates.
        scale_x, scale_y = im.width / 1448, im.height / 1086
    else:
        scale_x = scale_y = 1
    # Trace the complete left hero shelf, including its upper sign/back panel and base.
    # The top edge follows the visible rim from (315,88) through (425,128) to (697,234).
    # Left points include the upper-left upright and product edge around (176,170)/(200,143).
    points = [(315,88),(425,128),(697,234),(721,247),(741,520),
              (520,596),(159,382),(158,345),(163,307),(176,257),
              (176,213),(176,170),(200,143),(314,125)]
    points = [(round(x*scale_x), round(y*scale_y)) for x,y in points]
    # Supersample the hand mask to keep the product silhouette edges smooth.
    aa = 4
    alpha_hi = Image.new('L', (im.width*aa, im.height*aa), 0)
    ImageDraw.Draw(alpha_hi).polygon([(x*aa,y*aa) for x,y in points], fill=255)
    alpha = alpha_hi.resize(im.size, Image.Resampling.LANCZOS)

    # Explicitly mask only callout strokes that touch or cross the retained shelf silhouette.
    masks = Image.new('L', im.size, 0)
    draw = ImageDraw.Draw(masks)
    strokes = [
        ([(220,106),(303,106),(331,121)], 7),        # upper-left green leader
        ([(444,139),(535,107)], 7),                  # upper-right orange leader
        ([(108,298),(157,298)], 7),                  # left blue leader and endpoint
        ([(280,457),(310,418)], 7),                     # visible part of lower-left orange leader
        ([(438,602),(470,602),(497,570)], 7),        # base green leader
    ]
    for xy, width in strokes:
        draw.line([(round(x*scale_x),round(y*scale_y)) for x,y in xy],
                  fill=255, width=max(3, round(width*min(scale_x,scale_y))), joint='curve')
    for x,y,radius in [(331,121,8),(444,139,8),(157,298,8),
                       (310,418,9),(497,570,9)]:
        x,y=round(x*scale_x),round(y*scale_y)
        r=round(radius*min(scale_x,scale_y))
        draw.ellipse((x-r,y-r,x+r,y+r), fill=255)
    # Remove green glyphs/box strokes in the known base-callout area without color-keying shelf
    # products elsewhere in the reference.
    rgb_source = np.asarray(im)
    hsv = cv2.cvtColor(rgb_source, cv2.COLOR_RGB2HSV)
    green_callout = cv2.inRange(hsv, np.array((30, 70, 55), np.uint8),
                                np.array((100, 255, 255), np.uint8))
    gx0,gy0=round(314*scale_x),round(104*scale_y)
    gx1,gy1=round(346*scale_x),round(136*scale_y)
    x0,y0=round(265*scale_x),round(560*scale_y)
    x1,y1=round(445*scale_x),round(642*scale_y)
    mask_array = np.asarray(masks).copy()
    mask_array[y0:y1,x0:x1] = np.maximum(mask_array[y0:y1,x0:x1], green_callout[y0:y1,x0:x1])
    green_marker_roi = np.zeros_like(green_callout)
    green_marker_roi[gy0:gy1,gx0:gx1] = green_callout[gy0:gy1,gx0:gx1]
    green_marker_roi = cv2.dilate(green_marker_roi, np.ones((3,3), np.uint8))
    mask_array = np.maximum(mask_array, green_marker_roi)
    # The lower orange leader crosses only the dark base/floor in this small source region.
    orange_leader = cv2.inRange(hsv, np.array((0, 100, 60), np.uint8),
                                np.array((25, 255, 255), np.uint8))
    marker_x0,marker_y0=round(300*scale_x),round(408*scale_y)
    marker_x1,marker_y1=round(322*scale_x),round(430*scale_y)
    orange_marker_roi = np.zeros_like(orange_leader)
    orange_marker_roi[marker_y0:marker_y1,marker_x0:marker_x1] = \
        orange_leader[marker_y0:marker_y1,marker_x0:marker_x1]
    orange_marker_roi = cv2.dilate(orange_marker_roi, np.ones((3,3), np.uint8))
    mask_array = np.maximum(mask_array, orange_marker_roi)
    ox0,oy0=round(276*scale_x),round(445*scale_y)
    ox1,oy1=round(300*scale_x),round(465*scale_y)
    mask_array[oy0:oy1,ox0:ox1] = np.maximum(mask_array[oy0:oy1,ox0:ox1],
                                               orange_leader[oy0:oy1,ox0:ox1])
    masks = Image.fromarray(mask_array)
    rgb = cv2.inpaint(rgb_source, mask_array, 3, cv2.INPAINT_TELEA)
    result = Image.fromarray(rgb).convert('RGBA')
    result.putalpha(alpha)
    # Sanitize hidden RGB too: some inference clients discard alpha before preprocessing.
    rgba = np.asarray(result).copy()
    rgba[rgba[:,:,3] == 0, :3] = (88,88,88)
    result = Image.fromarray(rgba, 'RGBA')
    bbox=alpha.getbbox()
    crop=(max(0,bbox[0]-12),max(0,bbox[1]-12),min(im.width,bbox[2]+12),min(im.height,bbox[3]+12))
    result.crop(crop).save(out/'shelf_gondola_input.png')
    im.crop(crop).save(out/'source_crop.png')
    masks.crop(crop).save(out/'annotation_mask.png')
    # Matte preview is the alpha result composited over neutral dark gray for edge inspection.
    preview_bg = Image.new('RGBA', result.size, (88,88,88,255))
    preview_bg.alpha_composite(result)
    preview_bg.crop(crop).convert('RGB').save(out/'matte_preview.png')
    (out/'preprocessing.json').write_text(json.dumps({
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_px':list(im.size),'crop':crop,'silhouette_polygon_px':points,
        'method':'hand-traced hero-shelf alpha; narrow localized OpenCV TELEA inpainting of listed leader lines and marker dots',
        'silhouette_scope':'Includes the visible upper sign/back panel and complete shelf/base; the bright diagonal panel is part of the source fixture, bounded by its visible rim.',
        'annotation_mask_regions':'Explicit leader strokes and endpoint dots; green callout hues selected only in source px boxes [265,560,445,642] and [314,104,346,136], orange leader hues only in visible in-silhouette segment [276,445,300,465] and marker [300,408,322,430]; no package-wide color key.',
        'preview_background_rgb':[88,88,88],
        'transparent_pixel_rgb':[88,88,88],
        'input_review':'NEEDS_PARENT_REVIEW','runtime_approved':False,
        'review_notes':'Source crop and generated matte preview visually compared. The mask follows the visible top-panel rim through source points (315,88), (425,128), and (697,234), and includes the upper-left upright/product edge via (176,170) and (200,143). Parent review is still required; no parent approval is claimed. Shelf geometry and dimensions are not validated.',
        'warning':'Inpainted pixels are synthesized preprocessing; this is not geometry or dimensional validation.'
    },indent=2)+'\n')


if __name__=='__main__':
    main()
