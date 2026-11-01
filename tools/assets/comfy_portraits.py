"""Head-and-shoulders portraits of the customers and the staff for the panels (#141 客パネル, #144 店員カード), rendered
by the local ComfyUI with the anima-style LoRA only (no character LoRA: these are fictional townspeople). Each
customer portrait follows the colours of its in-store look (customer_a / b / c sprites), so the panel and the
figure in the store match. Raw renders go to assets/source/characters/portraits/ with a .json of the prompt.

    python tools/assets/comfy_portraits.py customer_a staff_1 ...   # ids, or "all"; --seed N (default 4101)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/characters/portraits")
COMMON = ("anima_style, solo, anime illustration, soft shading, delicate lineart, gentle highlights, "
          "head and shoulders portrait, bust shot, facing the viewer, centered, friendly natural expression, "
          "plain pure white background, simple background")
PEOPLE = {
    # customers: the colours of assets/generated/characters/customer_*/ (blue sweater / salmon top + green bag / yellow)
    "customer_a": "1boy, young man in his twenties, short dark brown hair, light blue crew-neck sweater, casual, ",
    "customer_b": "1girl, young woman, short light brown bob hair, salmon pink blouse, green shoulder bag strap, ",
    "customer_c": "1boy, older man in his sixties, short grey hair, kind wrinkles, pale yellow cardigan over a shirt, ",
    # staff: the teal store uniform of the clerk sprite, with a small name tag
    "staff_1": "1boy, young man, short black hair, teal convenience store uniform shirt, small name tag, ",
    "staff_2": "1girl, young woman, brown hair in a low ponytail, teal convenience store uniform shirt, small name tag, ",
    "staff_3": "1girl, woman in her forties, short dark bob hair, gentle smile, teal convenience store uniform shirt, small name tag, ",
    "staff_4": "1boy, university student, glasses, messy dark hair, teal convenience store uniform shirt, small name tag, ",
    # the more looks of #104 (the chibi_* figures of the same ids)
    "elderly_woman": "1girl, elderly woman in her seventies, short permed grey hair, lavender cardigan, small handbag, ",
    "worker": "1boy, construction worker, short black hair, white towel around the neck, mustard yellow work jacket, ",
    "uni_student": "1boy, university student, messy brown hair, grey hoodie, backpack, ",
    "young_woman": "1girl, young woman in her twenties, long dark brown hair, beige trench coat, ",
    "office_worker": "1boy, office worker in his thirties, short neat black hair, navy business suit, white shirt, blue tie, ",
    "student": "1girl, japanese high school student, long black hair in a ponytail, navy sailor school uniform with a red ribbon, ",
    "parent": "1girl, mother in her thirties, shoulder-length brown hair, beige knit sweater, ",
}
NEGATIVE = ("low quality, worst quality, malformed face, distorted face, extra eyes, cropped head, out of frame, hands, "
            "text, watermark, logo, signature, busy background, scenery, other people, koharu_rikka, grey hair double bun")
SIZE = 512


def generate(person: str, seed: int) -> Path:
    positive = PEOPLE[person] + COMMON
    wf = comfy.graph(positive, NEGATIVE, seed, "portrait_%s_%d" % (person, seed), SIZE, SIZE, False)
    return comfy.run(wf, OUT / ("%s_%d.png" % (person, seed)), {"person": person, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 4101
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    people = list(PEOPLE) if args == ["all"] else args
    for p in people:
        print(generate(p, seed))
