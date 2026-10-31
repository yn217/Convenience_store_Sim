"""Anime chibi figures for the people in the store (customers and the clerk), replacing the box placeholders: one
three-quarter front view and one three-quarter back view per person, both facing left, on white, rendered by the
local ComfyUI (anima-style LoRA only). tools/assets/build_chibi_sprites.py cuts them out, mirrors them for the other
two facings and writes the sprite frames. The colours follow the old looks so the portraits (#141) still match.

    python tools/assets/comfy_chibi.py all            # or ids: customer_a clerk ...; --seed N (default 6101)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/characters/chibi")
STYLE = ("anima_style, solo, chibi, super deformed, cute anime game character, full body, standing, "
         "simple clean lineart, flat soft cel shading, plain pure white background, no shadow, ")
PEOPLE = {
    "customer_a": "1boy, young man, short dark brown hair, light blue sweater, grey trousers, dark shoes, ",
    "customer_b": "1girl, young woman, short light brown bob hair, salmon pink blouse, green shoulder bag, beige trousers, dark shoes, ",
    "customer_c": "1boy, older man, short grey hair, pale yellow cardigan, dark grey trousers, dark shoes, ",
    "clerk": "1boy, young man, short black hair, teal convenience store uniform shirt with a small name tag, dark navy trousers, black shoes, ",
}
VIEWS = {
    "front": "three-quarter view from the front, body turned to the left, looking to the left, ",
    "back": "view from behind, three-quarter back view, walking away to the upper left, back of the head visible, face not visible, ",
}
NEGATIVE = ("low quality, worst quality, blurry, multiple views, reference sheet, text, watermark, logo, cropped feet, "
            "out of frame, background scenery, floor, shadow, extra limbs, malformed hands")


def generate(person: str, view: str, seed: int) -> Path:
    positive = STYLE + PEOPLE[person] + VIEWS[view]
    wf = comfy.graph(positive, NEGATIVE, seed, "chibi_%s_%s_%d" % (person, view, seed), 512, 768, False)
    return comfy.run(wf, OUT / ("%s_%s_%d.png" % (person, view, seed)), {"person": person, "view": view, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 6101
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    for p in (list(PEOPLE) if args == ["all"] else args):
        for v in VIEWS:
            print(generate(p, v, seed))
