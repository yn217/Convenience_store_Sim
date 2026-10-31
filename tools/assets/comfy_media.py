"""Thumbnails for the 媒体広告 card (#136): 小春六花 as the store's ad character in each medium, rendered by the local
ComfyUI (Koharu LoRA 0.8 + anima-style LoRA 0.8), 768x432, no text. Raw renders go to assets/source/media/ with the
prompt beside each; tools/assets/build_scene_ui.py scales them to 192x108 for a 128x72 slot.

    python tools/assets/comfy_media.py        # all four; --seed N (default 7101)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/media")
RIKKA = ("koharu_rikka, anima_style, 1girl, solo, grey hair, purple eyes, double bun, short hair, small pink round hair clip, "
         "white short-sleeved collared shirt, navy blue apron with thin white vertical stripes, anime illustration, ")
MEDIA = {
    "newspaper": "a folded newspaper flyer on a table showing an illustration of her smiling and pointing, warm morning light, paper texture, no readable text",
    "radio": "she is speaking into a studio radio microphone with headphones on, cheerful, radio studio, on air lamp glowing",
    "web_ads": "a smartphone screen showing her waving cheerfully, social media style, bright colorful icons around, no readable text",
    "television": "a television screen in a living room showing her waving inside a bright convenience store, tv commercial, warm colors",
}
# #140 / #137: promotions with a picture (fairs, the mascot collab, gifts, the stamp rally). The mascot is a fictional
# local character made for this game (a round orange tanuki in a convenience store apron), not a real one.
PROMOS = {
    "fair_autumn": RIKKA + "autumn food fair display, chestnut sweets, sweet potato desserts, maple leaves, warm orange light, she smiles beside the display",
    "fair_winter": RIKKA + "winter warm food fair, steaming oden pot, cup noodles, hot drinks, snowflakes outside the window, she holds a hot can, cozy",
    "fair_summer": RIKKA + "summer cool fair, ice pops and cold drinks in a cooler with ice, blue sky, wind chime, she holds an ice pop, refreshing",
    "fair_regional": RIKKA + "local gourmet fair, special bento boxes and onigiri on a decorated shelf with paper lanterns, she presents them proudly",
    "collab_mascot": RIKKA + "she hugs a big plush of a cute round orange tanuki mascot character wearing a tiny convenience store apron, limited goods and snacks around them",
    "gift_clearfile": RIKKA + "she shows a cute clear file folder with a pastel illustration, snack bags beside her, gift campaign, sparkles",
    "gift_sticker": RIKKA + "she holds up a sheet of cute round stickers, cold drink bottles beside her, gift campaign, sparkles",
    "stamps_lunch": RIKKA + "she holds a stamp card with round stamps and a small mascot mini towel, onigiri on the counter, stamp rally",
}
NEGATIVE = ("low quality, worst quality, blurry, text, letters, words, logo, brand name, watermark, signature, malformed hands, "
            "extra fingers, distorted face, other people")


def generate_promo(def_id: str, seed: int) -> Path:
    wf = comfy.graph(PROMOS[def_id], NEGATIVE, seed, "promo_%s_%d" % (def_id, seed), 768, 432, True)
    return comfy.run(wf, Path("assets/source/promotions") / ("%s_%d.png" % (def_id, seed)),
                     {"promotion": def_id, "seed": seed, "loras": {"Koharu-Koharu-epoch100": 0.8, "anima-style-epoch35-lr5e5": 0.8}})


def generate(medium: str, seed: int) -> Path:
    wf = comfy.graph(RIKKA + MEDIA[medium], NEGATIVE, seed, "media_%s_%d" % (medium, seed), 768, 432, True)
    return comfy.run(wf, OUT / ("%s_%d.png" % (medium, seed)),
                     {"medium": medium, "seed": seed, "loras": {"Koharu-Koharu-epoch100": 0.8, "anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = int(args[args.index("--seed") + 1]) if "--seed" in args else 7101
    if "--promos" in args:
        for d in PROMOS:
            print(generate_promo(d, seed))
    else:
        for m in MEDIA:
            print(generate(m, seed))
