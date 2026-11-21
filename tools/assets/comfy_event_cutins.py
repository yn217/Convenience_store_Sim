"""Special event CGs with Koharu Rikka for the konbini game (2026-11-21).

Anima Base + Koharu LoRA + anima style LoRA on the separate ComfyUI at 8189, 1344x768, the setup of the
earlier event CGs (issue30_31_32_comfyui), but with the in-game look: two small hair buns, pink hairpin,
white short-sleeve shirt, navy pinstripe apron.

  python comfy_event_cutins.py             # the start cut-ins: all events, SEEDS each
  python comfy_event_cutins.py hot_day     # one event
  python comfy_event_cutins.py --choices   # the event choice pictures (the morning ask): CHOICES, CHOICE_SEEDS
"""
import json, sys, time, urllib.request, pathlib, shutil

URL = "http://127.0.0.1:8189"
OUT = pathlib.Path("F:/Stable Diffusion/game-assets/event_cg_koharu_20261121/out")
COMFY_OUT = pathlib.Path("F:/Stable Diffusion/ComfyUI-Windows/ComfyUI_windows_portable/ComfyUI/output")
SEEDS = [2611211, 2611212]

CHAR = (
    "koharu_rikka, anima_style, masterpiece, best quality, detailed anime visual novel game event CG, "
    "1girl, solo, Koharu Rikka, silver gray hair, medium hair with bangs, double bun, two small hair buns on top of head, "
    "pink heart hairpin, pink eyes, white collared short sleeve shirt, navy blue pinstripe apron with a small name tag, "
)
NEG = (
    "worst quality, low quality, blurry, photorealistic, 3d render, bad anatomy, extra fingers, missing fingers, "
    "fused fingers, deformed hands, extra limbs, duplicate girl, multiple girls, wrong hair color, long hair, ribbon bow tie, "
    "american convenience store, gas station, supermarket, restaurant, "
    "washed out colors, overexposure, unfinished background, distorted perspective, "
    "real brand logos, recognizable store chain, text, letters, gibberish text, watermark, signature"
)

EVENTS = {
    "local_fair": (
        "summer festival night in front of a small Japanese neighborhood convenience store, paper lanterns strung overhead, "
        "festival stalls and a red torii in the distance, warm orange lantern light, "
        "she wears a light blue happi festival coat over her apron and a towel headband, holding a tray of cold ramune bottles, "
        "big cheerful smile, waving to festival visitors, dynamic angle, festive lively atmosphere, fireworks in the night sky"),
    "hot_day": (
        "scorching midsummer afternoon, bright blue sky with cumulonimbus clouds, heat haze over the asphalt, "
        "she stands in front of the open glass door of a Japanese convenience store, cool air from the store, "
        "holding an ice pop in one hand and a cold sweating plastic drink bottle against her cheek, "
        "slight sweat, happy relieved expression, cicadas season, vivid summer colors, sunlight and strong shadows"),
    "cold_day": (
        "snowy winter evening inside a cozy Japanese convenience store, snow falling outside the large front window, "
        "she stands behind the counter next to a steaming oden pot, holding a small paper cup of oden with chopsticks, "
        "red cheeks, white breath, gentle warm smile, warm yellow store lighting contrasting with blue snow outside, "
        "soft steam rising, heartwarming atmosphere"),
    "sudden_rain": (
        "sudden heavy rain shower, view from inside a Japanese convenience store entrance, rain streaking down the glass door, "
        "wet street and puddles outside, she hurriedly carries an armful of clear plastic vinyl umbrellas to a umbrella stand by the door, "
        "surprised but determined expression, droplets, cool blue gray light with warm store light inside, dynamic motion"),
    "onigiri_festa": (
        "rice ball festival campaign inside a bright Japanese convenience store, colorful paper decorations and plain blank pop cards, "
        "she proudly holds up two triangle shaped onigiri rice balls wrapped with a black nori seaweed strip, in clear plastic film, toward the viewer, "
        "a chilled shelf packed with rows of triangle onigiri with black nori behind her, wink, very cheerful energetic pose, "
        "bright clean lighting, celebratory sparkles"),
    "sweets_spotlight": (
        "spring sweets fair inside a Japanese convenience store, cherry blossom pink decorations, sakura petals drifting, "
        "she holds a small plastic cup of strawberry parfait dessert close to her face with both hands, "
        "eyes sparkling, blushing delighted smile, chilled dessert shelf with cute pastel desserts behind her, "
        "soft pastel pink lighting, dreamy cute atmosphere"),
    "after_work": (
        "evening after work rush, orange sunset light through the front window of a Japanese convenience store, "
        "she stands at the register counter smiling warmly toward the viewer as if greeting a tired office worker, "
        "hot snack showcase with fried chicken beside the register, long warm shadows, "
        "calm gentle relaxed atmosphere, golden hour glow"),
}


## The event choice screen (assets/runtime/event_choices, 2026-11-21): before the event, she gets ready or wonders
## what to do; the nine events that ask the player.
CHOICE_SEEDS = [2611221, 2611222]
CHOICES = {
    "evt_local_fair": (
        "late afternoon in front of a small Japanese neighborhood convenience store, people hanging red paper lanterns along the street, "
        "she holds a plain festival flyer with both hands and looks at the viewer with an excited questioning smile, "
        "a festival tent being set up in the background, warm sunset light, anticipation"),
    "evt_roadworks": (
        "road construction right in front of a small Japanese convenience store, orange traffic cones and yellow barriers, "
        "a small excavator and construction workers in helmets in the background, dust, "
        "she stands at the store entrance holding a clipboard, troubled thinking expression with a finger on her chin, daytime"),
    "evt_hot_day": (
        "hot summer morning inside a Japanese convenience store, strong sunlight through the front window, "
        "she fans herself with a hand fan in front of an open glass drink refrigerator full of plastic bottles, "
        "checking the stock, slight sweat, determined smile, bright summer colors"),
    "evt_cold_day": (
        "frosty winter morning at the entrance of a Japanese convenience store, frost on the glass door, "
        "she wears a red knitted scarf over her uniform and blows white breath into her cupped hands, "
        "rosy cheeks, cozy warm store light behind her, pale blue cold morning outside"),
    "evt_neighbor_mentions": (
        "sunny day in front of a small Japanese neighborhood convenience store, two neighborhood women chatting happily by the entrance "
        "in the background, she peeks out from the door holding a smartphone to her chest, "
        "pleasantly surprised happy blush, sparkles, friendly local atmosphere"),
    "evt_after_work": (
        "late afternoon inside a Japanese convenience store, orange light through the window, "
        "she arranges fried chicken pieces into the hot snack showcase next to the register with tongs, "
        "focused gentle expression, getting ready for the evening rush, warm lighting"),
    "evt_gourmet_fair": (
        "local gourmet fair inside a Japanese convenience store, a special table display of regional bento boxes and local specialty snacks, "
        "plain colorful paper banners without text, she holds up a fancy regional bento box toward the viewer, "
        "proud cheerful smile, bright lively atmosphere"),
    "evt_sudden_rain": (
        "dark rain clouds gathering outside the large front window of a Japanese convenience store, the street getting dim, "
        "she looks up at the sky through the window holding a folded clear vinyl umbrella, slightly worried expression, "
        "cool gray light outside, warm light inside"),
    "evt_onigiri_festa": (
        "early morning inside a bright Japanese convenience store, morning sunlight, "
        "she happily lines up triangle onigiri rice balls wrapped with a black nori seaweed strip in clear plastic film on a chilled shelf, "
        "excited smile, a small wall television in the corner showing a blurry bowl of rice, fresh morning atmosphere"),
}


def graph(prompt: str, seed: int, prefix: str) -> dict:
    return {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "Anima-Base-v1.0.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_06b_base.safetensors", "type": "qwen_image"}},
        "3": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["1", 0], "lora_name": "Koharu-Koharu-epoch100.safetensors", "strength_model": 0.8}},
        "4": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["3", 0], "lora_name": "anima-style-epoch35-lr5e5.safetensors", "strength_model": 0.8}},
        "5": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": prompt}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["2", 0], "text": NEG}},
        "7": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1344, "height": 768, "batch_size": 1}},
        "8": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "positive": ["5", 0], "negative": ["6", 0], "latent_image": ["7", 0],
                                                  "seed": seed, "steps": 24, "cfg": 4.5, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "9": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "10": {"class_type": "VAEDecode", "inputs": {"samples": ["8", 0], "vae": ["9", 0]}},
        "11": {"class_type": "SaveImage", "inputs": {"images": ["10", 0], "filename_prefix": prefix}},
    }


def post(path, body):
    req = urllib.request.Request(URL + path, json.dumps(body).encode(), {"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(req).read() or b"{}")


def get(path):
    return json.loads(urllib.request.urlopen(URL + path).read())


def main():
    global OUT, EVENTS, SEEDS
    args = sys.argv[1:]
    tag = "cutin"
    if "--choices" in args:
        args.remove("--choices")
        OUT, EVENTS, SEEDS, tag = OUT.parent / "choices_out", CHOICES, CHOICE_SEEDS, "choice"
    OUT.mkdir(exist_ok=True)
    names = args or list(EVENTS)
    jobs = []
    for name in names:
        for seed in SEEDS:
            prefix = f"koharu_event_20261121/{tag}_{name}_s{seed}"
            r = post("/prompt", {"prompt": graph(CHAR + EVENTS[name], seed, prefix)})
            jobs.append((r["prompt_id"], name, seed))
    print(f"queued {len(jobs)}", flush=True)
    for pid, name, seed in jobs:
        t0 = time.time()
        while True:
            h = get(f"/history/{pid}")
            if pid in h:
                break
            time.sleep(3)
        for node in h[pid]["outputs"].values():
            for im in node.get("images", []):
                src = COMFY_OUT / im["subfolder"] / im["filename"]
                dst = OUT / f"{name}_s{seed}.png"
                shutil.copy(src, dst)
                print(f"{dst.name}  {time.time() - t0:.0f}s", flush=True)
    meta = {"model": "Anima-Base-v1.0", "loras": {"Koharu-Koharu-epoch100": 0.8, "anima-style-epoch35-lr5e5": 0.8},
            "sampler": "euler/simple 24 steps cfg 4.5", "size": [1344, 768], "seeds": SEEDS,
            "character": CHAR, "negative": NEG, "events": {n: EVENTS[n] for n in names}}
    (OUT / "prompts.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
