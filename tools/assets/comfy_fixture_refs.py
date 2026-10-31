"""Reference images for the Idol image-to-3D step (tools/assets/idol/): one fixture per image, a plain 3D product
render (no anime outlines: the outlines would be baked onto the splats and sit on the wrong edges once the model is
turned), three-quarter front view from a little above, whole object in frame, on white. Rendered by the local ComfyUI
with Anima-Base and no LoRA. Raw renders + prompt records go to assets/source/idol_refs/.

    python tools/assets/comfy_fixture_refs.py crane_game capsule_toy_1 ...   # or "all"; --seed N (default 9101)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/idol_refs")
STYLE = ("realistic 3d render, product visualization, single object, isolated, three-quarter front view from slightly above, "
         "the whole object in frame with margin, soft even studio lighting, plain pure white background, clean surfaces, "
         "japanese convenience store equipment, ")
FIXTURES = {
    "fridge_daily": "a long open-front multideck refrigerated display case for chilled lunch boxes, salads and dairy, "
                    "white body, four shelves stocked with colourful packaged food, no doors, wide and low, ",
    "capsule_toy_1": "a single capsule toy vending machine, gachapon, clear dome full of colourful capsules on a pink stand with a coin dial, ",
    "capsule_toy_3": "exactly three small capsule toy vending machines in one straight row side by side, gachapon, pink and white cabinets, clear windows full of colourful capsules, ",
    "capsule_toy_5": "a long row of five capsule toy vending machines side by side, gachapon, pink white and yellow cabinets, clear windows full of colourful capsules, ",
    "shelf_goods": "a tall store shelf of daily goods, towels, socks, toiletries and stationery in neat rows, white metal gondola shelf, "
                   "front facing the viewer, ",
    "soft_serve_machine": "a soft serve ice cream machine on a small white counter cabinet, stainless steel, two levers, a vanilla cone on the drip tray, ",
    "frappe_blender": "a frappe drink station, a blender with a pink smoothie and a cup dispenser on a small white counter cabinet, ",
    "bakery_oven": "an in-store bakery corner, a stainless bake oven on top of a long glass bread display case with croissants and melon pan, ",
    "pizza_oven": "a compact countertop pizza oven on a small white counter cabinet, a pizza visible through the oven door, ",
    "eat_in_counter": "a single straight eat-in bar counter, one long narrow light wooden bar table in a straight line, not l-shaped, three tall bar stools in a row in front of it, ",
    "eat_in_table": "a small cafe table set for two people, one small light wooden rectangular table with only two chairs, one chair on each side, ",
    "crane_game": "a crane game claw machine, glass cabinet with plush toys inside, pink and white cabinet with lights, coin slot and joystick in front, ",
    "staff_room_s": "a small backroom office cubicle with low partition walls only waist high, a desk with a computer, a chair and a locker, open top, ",
    "staff_room_m": "a backroom staff area with low partition walls only waist high, a desk with a computer, lockers, a small table with chairs, open top, ",
    "staff_room_l": "a large backroom staff area with low partition walls only waist high, two desks with computers, a row of lockers, "
                    "a break table with chairs, shelves with boxes, open top, ",
}
NEGATIVE = ("anime, cartoon, lineart, outlines, ink lines, cel shading, illustration, sketch, low quality, worst quality, blurry, text, "
            "letters, logo, brand name, watermark, people, person, hands, background scenery, room, wall, floor, cropped, out of frame, "
            "multiple views")
SIZE = 1024


def generate(fixture: str, seed: int) -> Path:
    positive = STYLE + FIXTURES[fixture]
    wf = comfy.graph(positive, NEGATIVE, seed, "idolref_%s_%d" % (fixture, seed), SIZE, SIZE, False)
    wf["8"]["inputs"]["model"] = ["1", 0]   # no style LoRA: a plain render, not the anime look
    del wf["4"]
    return comfy.run(wf, OUT / ("%s_%d.png" % (fixture, seed)), {"type_id": fixture, "seed": seed, "loras": {}, "base": "Anima-Base-v1.0",
                                                               "size": [SIZE, SIZE], "positive": positive, "negative": NEGATIVE})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 9101
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    for f in (list(FIXTURES) if args == ["all"] else args):
        print(generate(f, seed))
