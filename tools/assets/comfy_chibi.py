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
    # more looks for #104 (多様な服装), 2026-10-31
    "office_worker": "1boy, office worker in his thirties, short neat black hair, navy business suit, white shirt, blue tie, black leather shoes, briefcase, ",
    "student": "1girl, japanese high school student, long black hair in a ponytail, navy sailor school uniform with a red ribbon, navy pleated skirt, white socks, loafers, school bag, ",
    "parent": "1girl, mother in her thirties, shoulder-length brown hair, beige knit sweater, light denim jeans, white sneakers, eco tote bag, ",
}
VIEWS = {
    "front": "three-quarter view from the front, body turned to the left, looking to the left, ",
    "back": "view from behind, three-quarter back view, walking away to the upper left, back of the head visible, face not visible, ",
    # the eat-in seat (#134): drawn for every facing (mirrored)
    "eat": "sitting on a tall wooden stool, eating an onigiri rice ball held in both hands, seen from the side, facing left, happy, ",
}
NEGATIVE = ("low quality, worst quality, blurry, multiple views, reference sheet, text, watermark, logo, cropped feet, "
            "out of frame, background scenery, floor, shadow, extra limbs, malformed hands")


def generate(person: str, view: str, seed: int) -> Path:
    positive = STYLE + PEOPLE[person] + VIEWS[view]
    wf = comfy.graph(positive, NEGATIVE, seed, "chibi_%s_%s_%d" % (person, view, seed), 512, 768, False)
    return comfy.run(wf, OUT / ("%s_%s_%d.png" % (person, view, seed)), {"person": person, "view": view, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8}})


STEPS = {   # two stride poses for the walk cycle, img2img from the standing render so the face and clothes stay
    "stepA": "walking briskly, taking a big step, legs wide apart in a long stride, front foot forward, back foot lifted on its toes, arms swinging, ",
    "stepB": "walking, passing pose, one knee raised, one foot lifted off the ground, arms swinging the other way, ",
}
STEP_DENOISE = 0.72


def _upload(path: Path) -> str:
    boundary = "----comfy%d" % abs(hash(str(path)))
    data = path.read_bytes()
    body = (("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\nContent-Type: image/png\r\n\r\n" % (boundary, path.name)).encode()
            + data + ("\r\n--%s\r\nContent-Disposition: form-data; name=\"overwrite\"\r\n\r\ntrue\r\n--%s--\r\n" % (boundary, boundary)).encode())
    import json as _json
    import urllib.request as _rq
    req = _rq.Request(comfy.URL + "/upload/image", data=body, headers={"Content-Type": "multipart/form-data; boundary=" + boundary})
    with _rq.urlopen(req, timeout=60) as r:
        return _json.load(r)["name"]


def generate_step(person: str, view: str, step: str, seed: int) -> Path:
    base = OUT / ("%s_%s_%d.png" % (person, view, seed))
    name = _upload(base)
    positive = STYLE + PEOPLE[person] + VIEWS[view] + STEPS[step]
    wf = comfy.graph(positive, NEGATIVE, seed, "chibi_%s_%s_%s_%d" % (person, view, step, seed), 512, 768, False)
    wf["12"] = {"class_type": "LoadImage", "inputs": {"image": name}}
    wf["13"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["12", 0], "vae": ["9", 0]}}
    wf["8"]["inputs"]["latent_image"] = ["13", 0]
    wf["8"]["inputs"]["denoise"] = STEP_DENOISE
    return comfy.run(wf, OUT / ("%s_%s_%s_%d.png" % (person, view, step, seed)),
                     {"person": person, "view": view, "step": step, "seed": seed, "img2img_from": base.name, "denoise": STEP_DENOISE,
                      "loras": {"anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__" and "--steps" in sys.argv:
    only = [a for a in sys.argv[1:] if a in PEOPLE]
    for p in (only or list(PEOPLE)):
        for v in ("front", "back"):   # strides only for the walking views
            for st in STEPS:
                print(generate_step(p, v, st, 6101))
    sys.exit(0)

if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 6101
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    views = list(VIEWS)
    if "--view" in args:
        i = args.index("--view")
        views = [args[i + 1]]
        del args[i:i + 2]
    for p in (list(PEOPLE) if args == ["all"] else args):
        for v in views:
            print(generate(p, v, seed))
