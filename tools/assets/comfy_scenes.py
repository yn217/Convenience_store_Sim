"""Anime background art for a more Japanese-game look (2026-10-31): the title screen background and one illustration
per daily event (今日のイベント card), rendered by the local ComfyUI with the anima-style LoRA only. No text, no
logos, no real brands. Raw renders go to assets/source/scenes/ with a .json of the prompt.

    python tools/assets/comfy_scenes.py title evt_local_fair ...   # ids, or "all"; --seed N (default 5101)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/scenes")
STYLE = ("anima_style, anime background art, japanese anime film background, detailed, soft light, beautiful colors, "
         "clean composition, no text, ")
SCENES = {
    # title: 1344x768 (about 1 MP), scaled to the 1920x1080 screen
    "title": ("a small japanese convenience store on a quiet residential street corner at dusk, warm light from the glass "
              "storefront, vending machines beside the door, utility poles and wires, bicycles parked, gradient evening sky "
              "with pink and purple clouds, streetlights turning on, wide shot, no people"),
    "evt_local_fair": "japanese summer festival street at dusk, rows of red paper lanterns, food stalls, small distant silhouettes of people in yukata, warm glow",
    "evt_roadworks": "japanese residential road under construction in daytime, orange traffic cones, striped barriers, small yellow excavator, blue sky",
    "evt_hot_day": "midsummer day, bright blue sky with tall cumulonimbus clouds, japanese street with heat haze, cold bottled drinks with water droplets and an ice pop in the foreground",
    "evt_cold_day": "cold winter morning, light snow falling on a japanese street, a steaming pot of oden on a convenience store counter in the foreground, warm steam",
    "evt_sweets_spotlight": "still life of japanese convenience store desserts on a shelf, custard pudding, cream puffs, roll cake, strawberry shortcake, soft pastel light",
    "evt_snack_buzz": "still life of colorful snack bags, chocolate and potato chips arranged on a convenience store shelf, cheerful bright light, plain unlabeled packages",
    "evt_neighbor_mentions": "a smartphone on a table showing heart and star icons, blurred friendly japanese neighborhood street in the background, warm afternoon light",
    "evt_quiet_street": "calm early morning on an empty japanese residential street, soft sunlight, a cat sleeping on a low wall, quiet atmosphere, no people",
    "evt_lunch_pick": "still life of onigiri rice balls wrapped in nori, sandwiches and bread rolls on a counter at noon, bright window light",
    "evt_drink_pick": "rows of colorful bottled drinks and canned tea in a glass refrigerated case, condensation, cool blue light, unlabeled bottles",
    "evt_bread_feature": "freshly baked japanese bakery breads, melon pan, curry bread, croissants on wooden trays, morning sunlight",
    "evt_after_work": "japanese city street at night, office workers walking home as small silhouettes, glowing convenience store light, neon reflections on the road",
}
NEGATIVE = ("low quality, worst quality, blurry, text, letters, words, signage text, logo, brand name, watermark, signature, "
            "deformed, distorted, close-up face, malformed hands")
SIZES = {"title": (1344, 768)}
EVENT_SIZE = (768, 432)


def generate(scene: str, seed: int) -> Path:
    w, h = SIZES.get(scene, EVENT_SIZE)
    wf = comfy.graph(STYLE + SCENES[scene], NEGATIVE, seed, "scene_%s_%d" % (scene, seed), w, h, False)
    return comfy.run(wf, OUT / ("%s_%d.png" % (scene, seed)), {"scene": scene, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 5101
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    for s in (list(SCENES) if args == ["all"] else args):
        print(generate(s, seed))
