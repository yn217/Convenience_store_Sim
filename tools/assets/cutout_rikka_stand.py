import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
src, dst = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
h, w, _ = im.shape
mn, mx = im.min(axis=2), im.max(axis=2)
bg = (mn >= 236) & ((mx - mn) <= 14)
lab, n = ndimage.label(bg)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
mask = np.isin(lab, list(border))
# enclosed pockets of pure white (gaps between hair strands) are background too
pure = (mn >= 248) & ((mx - mn) <= 6)
plab, pn = ndimage.label(pure)
sizes = ndimage.sum(pure, plab, range(1, pn + 1))
cents = ndimage.center_of_mass(pure, plab, range(1, pn + 1))
# the face (centre band) keeps its highlights
big = [i + 1 for i, s in enumerate(sizes) if s >= 120 and not (0.30 * w <= cents[i][1] <= 0.76 * w)]
mask |= np.isin(plab, big) & bg
alpha = np.where(mask, 0.0, 1.0)
# colour-to-alpha against white in a band next to the background: removes the white fringe
band = ndimage.binary_dilation(mask, iterations=4) & ~mask
wa = np.clip((255.0 - mn) / 70.0, 0, 1)
alpha = np.where(band, np.minimum(alpha, wa), alpha)
rgb = im.copy()
safe = np.maximum(alpha, 1e-3)[..., None]
un = np.clip((im - 255.0 * (1 - alpha[..., None])) / safe, 0, 255)
rgb = np.where(band[..., None], un, im)
alpha = ndimage.gaussian_filter(alpha, 0.7)
fade_from, fade_to = int(h * 0.80), int(h * 0.97)
ramp = np.ones(h, np.float32)
ramp[fade_from:fade_to] = np.linspace(1, 0, fade_to - fade_from)
ramp[fade_to:] = 0
alpha = alpha * ramp[:, None]
out = np.dstack([rgb.astype(np.uint8), (alpha * 255).astype(np.uint8)])
Image.fromarray(out, "RGBA").crop((0, 0, w, fade_to)).save(dst)
print("saved", dst, w, fade_to, "pockets", len(big))
