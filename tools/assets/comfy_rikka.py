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
    # extra poses (2026-10-31): explaining for the tutorial and story lines, welcoming for the title screen
    "point": "cheerful smile, explaining, index finger raised beside her face, other hand on her hip, looking at viewer, ",
    "welcome": "warm welcoming smile, slight bow, both hands together in front of her apron, looking at viewer, ",
}
HAIRPIN = "small pink round hair clip on her hair, "   # the clip came out pink or blue; asked for pink to match
NEGATIVE = ("low quality, worst quality, malformed hands, extra fingers, missing fingers, fused fingers, extra arms, "
            "duplicate limbs, distorted face, cropped head, out of frame, text, watermark, logo, signature, "
            "busy background, scenery, room, shelves, other people")
WIDTH, HEIGHT = 640, 960


def workflow(expression: str, seed: int) -> dict:
    prefix = "rikka_%s_%d" % (expression, seed)
    return graph(CHARACTER + HAIRPIN + EXPRESSIONS[expression] + FRAMING, NEGATIVE, seed, prefix, WIDTH, HEIGHT, True)


## The API graph: Anima base + (Koharu LoRA when `rikka`) + anima-style LoRA, both at 0.8 as in the user's workflow.
def graph(positive: str, negative: str, seed: int, prefix: str, width: int, height: int, rikka: bool) -> dict:
    style_from = ["3", 0] if rikka else ["1", 0]
    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "Anima-Base-v1.0.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_06b_base.safetensors", "type": "qwen_image"}},
        "3": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "Koharu-Koharu-epoch100.safetensors", "strength_model": 0.8}},
        "4": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": style_from, "lora_name": "anima-style-epoch35-lr5e5.safetensors", "strength_model": 0.8}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": positive}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": negative}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["7", 0],
                                                    "seed": seed, "steps": 24, "cfg": 4.5, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "9": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["9", 0]}},
        "11": {"class_type": "SaveImage", "inputs": {"images": ["10", 0], "filename_prefix": prefix}},
    }
    if not rikka:
        del g["3"]
    return g


def _post(path: str, body: dict) -> dict:
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def _get(path: str) -> bytes:
    with urllib.request.urlopen(URL + path, timeout=60) as r:
        return r.read()


def generate(expression: str, seed: int) -> Path:
    return run(workflow(expression, seed), OUT / ("rikka_%s_%d.png" % (expression, seed)),
               {"expression": expression, "seed": seed, "loras": {"Koharu-Koharu-epoch100": 0.8, "anima-style-epoch35-lr5e5": 0.8}})


## Queues one graph, waits, downloads the image to `dst` and writes the prompt record beside it.
def run(wf: dict, dst: Path, meta: dict) -> Path:
    pid = _post("/prompt", {"prompt": wf})["prompt_id"]
    for _ in range(600):
        h = json.loads(_get("/history/" + pid))
        if pid in h and h[pid].get("outputs"):
            img = h[pid]["outputs"]["11"]["images"][0]
            q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""), "type": img["type"]})
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(_get("/view?" + q))
            rec = dict(meta)
            rec.update({"comfy_output": img["filename"], "positive": wf["5"]["inputs"]["text"], "negative": wf["6"]["inputs"]["text"],
                        "base": "Anima-Base-v1.0", "size": [wf["7"]["inputs"]["width"], wf["7"]["inputs"]["height"]],
                        "steps": 24, "cfg": 4.5, "sampler": "euler/simple"})
            dst.with_suffix(".json").write_text(json.dumps(rec, ensure_ascii=False, indent=2), encoding="utf-8")
            return dst
        time.sleep(1)
    raise TimeoutError(pid)


if __name__ == "__main__":
    expr = sys.argv[1]
    for s in sys.argv[2:]:
        print(generate(expr, int(s)))
