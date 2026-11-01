"""Cuts a figure out of a picture with Idol's BiRefNet (the background-removal model of speridlabs/idol, already in the
local Hugging Face cache). Run with the Idol venv:

    F:/AI_Tools/idol-sdk/.venv/Scripts/python.exe -I tools/assets/idol/cutout.py <in.png> <out.png> [x0 y0 x1 y1]

The optional box crops the input first; the output is RGBA at the crop's size.
"""
import glob
import os
import sys

import torch
from PIL import Image
from safetensors.torch import load_file

sys.path.insert(0, "F:/AI_Tools/idol-sdk")
from idol.models.birefnet import BiRefNet  # noqa: E402


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    im = Image.open(src).convert("RGB")
    if len(sys.argv) >= 7:
        im = im.crop(tuple(int(v) for v in sys.argv[3:7]))
    weights = glob.glob(os.path.expanduser("~/.cache/huggingface/hub/models--speridlabs--idol/snapshots/*/birefnet.safetensors"))[0]
    dev = "cuda" if torch.cuda.is_available() else "cpu"
    net = BiRefNet()
    net.load_state_dict(load_file(weights), strict=True)
    net = net.eval().requires_grad_(False).to(dev)
    if dev == "cuda":
        net.half()
    net.remove_background(im).save(dst)


if __name__ == "__main__":
    main()
