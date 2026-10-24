"""Border flood-fill cutout for studio renders on a flat light background (no ML matting model)."""
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

def cutout(src, dst, tol):
    im = np.asarray(Image.open(src).convert("RGB")).astype(np.int16)
    h, w, _ = im.shape
    border = np.concatenate([im[0], im[-1], im[:, 0], im[:, -1]])
    bg = np.median(border, axis=0)
    # background candidates: close to the local background colour and low saturation
    diff = np.abs(im - bg).max(axis=2)
    sat = im.max(axis=2) - im.min(axis=2)
    gray = ndimage.gaussian_filter(im.mean(axis=2).astype(np.float32), 1.2)
    grad = np.hypot(ndimage.sobel(gray, 0), ndimage.sobel(gray, 1))
    # plain background, or a soft floor shadow: grey, fairly bright and without edges
    cand = ((diff <= tol) & (sat <= 14)) | ((sat <= 12) & (gray >= 150) & (grad <= tol))
    lab, _ = ndimage.label(cand)
    edge_labels = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bgmask = np.isin(lab, edge_labels[edge_labels > 0])
    fg = ~bgmask
    fg = ndimage.binary_opening(fg, iterations=2)
    fg = ndimage.binary_fill_holes(fg)
    # keep the largest component (drops floor shadow specks)
    lab2, n = ndimage.label(fg)
    if n > 1:
        sizes = ndimage.sum(fg, lab2, range(1, n + 1))
        fg = lab2 == (np.argmax(sizes) + 1)
    alpha = Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
    out = Image.open(src).convert("RGBA")
    out.putalpha(alpha)
    out.save(dst)
    print(dst, "bg", bg, "fg_frac %.3f" % fg.mean())

if __name__ == "__main__":
    cutout(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 18)
