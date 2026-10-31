"""Generates the manager assistant (小春六花) figures with the local ComfyUI (Anima base + Koharu and anima-style
LoRAs at 0.8, the user's setup) and saves the raw images under assets/source/characters/koharu_rikka/generated/.

    python tools/assets/comfy_rikka.py normal 101 102 103     # expression, then seeds
    python tools/assets/comfy_rikka.py happy 101

Every image gets a .json next to it with the exact prompt, seed and models, so it can be made again.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

URL = "http://127.0.0.1:8188"
OUT = Path("assets/source/characters/koharu_rikka/generated")
CHARACTER = ("koharu_rikka, anima_style, 1girl, solo, grey hair, purple eyes, double bun, short hair, hair ornament, "
             "anime illustration, soft shading, delicate lineart, gentle highlights, "
             "convenience store clerk, white short-sleeved collared shirt, navy blue apron with thin white vertical stripes, "
             "small name tag on the apron, ")
FRAMING = ("cowboy shot, upper body to thighs, standing, facing the viewer, centered, full head visible with margin above, "
           "plain pure white background, simple background, no shadow on the background")
EXPRESSIONS = {
    "normal": "gentle friendly smile, closed mouth, looking at viewer, one hand raised slightly in a welcoming gesture, ",
    "happy": "very happy, big open-mouth smile, eyes bright, both hands in small fists at chest level, cheerful celebrating pose, ",
    "worried": "worried troubled smile, eyebrows lowered, one hand on her cheek, small sweat drop, looking at viewer, ",
}
NEGATIVE = ("low quality, worst quality, malformed hands, extra fingers, missing fingers, fused fingers, extra arms, "
            "duplicate limbs, distorted face, cropped head, out of frame, text, watermark, logo, signature, "
            "busy background, scenery, room, shelves, other people")
WIDTH, HEIGHT = 640, 960


def workflow(expression: str, seed: int) -> dict:
    prefix = "rikka_%s_%d" % (expression, seed)
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "Anima-Base-v1.0.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_06b_base.safetensors", "type": "qwen_image"}},
        "3": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "Koharu-Koharu-epoch100.safetensors", "strength_model": 0.8}},
        "4": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["3", 0], "lora_name": "anima-style-epoch35-lr5e5.safetensors", "strength_model": 0.8}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": CHARACTER + EXPRESSIONS[expression] + FRAMING}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": NEGATIVE}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": WIDTH, "height": HEIGHT, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["7", 0],
                                                    "seed": seed, "steps": 24, "cfg": 4.5, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "9": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["9", 0]}},
        "11": {"class_type": "SaveImage", "inputs": {"images": ["10", 0], "filename_prefix": prefix}},
    }


def _post(path: str, body: dict) -> dict:
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def _get(path: str) -> bytes:
    with urllib.request.urlopen(URL + path, timeout=60) as r:
        return r.read()


def generate(expression: str, seed: int) -> Path:
    wf = workflow(expression, seed)
    pid = _post("/prompt", {"prompt": wf})["prompt_id"]
    for _ in range(600):
        h = json.loads(_get("/history/" + pid))
        if pid in h and h[pid].get("outputs"):
            img = h[pid]["outputs"]["11"]["images"][0]
            q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img["type"]})
            OUT.mkdir(parents=True, exist_ok=True)
            dst = OUT / ("rikka_%s_%d.png" % (expression, seed))
            dst.write_bytes(_get("/view?" + q))
            dst.with_suffix(".json").write_text(json.dumps({"expression": expression, "seed": seed, "comfy_output": img["filename"],
                                                             "positive": wf["5"]["inputs"]["text"], "negative": NEGATIVE,
                                                             "base": "Anima-Base-v1.0", "loras": {"Koharu-Koharu-epoch100": 0.8, "anima-style-epoch35-lr5e5": 0.8},
                                                             "size": [WIDTH, HEIGHT], "steps": 24, "cfg": 4.5, "sampler": "euler/simple"},
                                                            ensure_ascii=False, indent=2), encoding="utf-8")
            return dst
        time.sleep(1)
    raise TimeoutError(pid)


if __name__ == "__main__":
    expr = sys.argv[1]
    for s in sys.argv[2:]:
        print(generate(expr, int(s)))
