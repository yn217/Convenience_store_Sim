"""UI art for the 2026-11-01 mockup (docs/mockups/ui_target_goods_2026-11-01.webp): the illustrated icons of the top
bar, the left menu and the bottom bar, the window's header pictures and the ranking crowns, one per image on white,
rendered by the local ComfyUI (anima-style LoRA 0.8, no text). tools/assets/build_ui_art.py cuts them out to the
sizes the UI draws them at.

    python tools/assets/comfy_ui_art.py            # all; or ids; --seed N (default 9401)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/ui_art")
STYLE = ("anima_style, cute sticker illustration, a single object, centered, whole object in frame, bold clean outline, "
         "bright saturated colours, soft gradient shading with a white highlight, plain pure white background, "
         "no text, no letters, no numbers, no square tile, no frame behind the object, ")
ICONS = {
    # left menu
    "nav_store": "a small cute convenience store building with a striped awning and a door, cream walls and brown roof",
    "nav_goods": "a light blue cardboard box, closed, with a white tape line",
    "nav_order": "a small white delivery truck seen from the side",
    "nav_management": "an orange and gold rising bar chart with an upward arrow",
    "nav_data": "a white and light blue bar chart with four bars",
    "nav_staff": "two white person silhouettes, one in front of the other",
    "nav_equipment": "a crossed silver wrench and screwdriver",
    "nav_achievement": "a shiny gold trophy cup with two handles",
    # top bar
    "logo_store": "a small cute japanese convenience store building with a cream striped awning, front view",
    "calendar": "a white desk calendar with a red top band and rings",
    "sakura": "a single pink cherry blossom flower with five petals",
    "moon": "a yellow crescent moon",
    "coins": "a small stack of shiny gold coins",
    "chart_blue": "a blue bar chart with four rising bars",
    "arrow_up": "a thick green upward arrow",
    "person": "a light blue person silhouette, head and shoulders",
    # window
    "clipboard": "a brown clipboard with a white paper checklist and a silver clip",
    "store_building": "a small brown wooden convenience store building with a flat roof and shop windows, front view",
    # bottom bar and data tab
    "flag": "a yellow flag on a short pole",
    "cart": "a light blue shopping cart",
    "people": "two light blue person silhouettes standing together",
    "chart_up": "an orange bar chart with a big green upward arrow",
    "bell": "a shiny gold bell",
    "mission": "a clipboard with a white checklist and a pencil",
    "book": "an open blue and white book",
    "basket": "a yellow shopping basket with handles",
    "crown_gold": "a small shiny gold crown",
    "crown_silver": "a small shiny silver crown",
    "crown_bronze": "a small shiny bronze crown",
    "pencil": "a small yellow pencil, diagonal",
}
NEGATIVE = ("low quality, worst quality, blurry, text, letters, words, numbers, logo, brand name, watermark, people, "
            "person, hands, background scenery, multiple objects, cropped, frame, border")
# The assistant beside the window (mockup: waist-up, clipboard on one arm, the other hand presenting the window).
PRESENT = ("happy open-mouth smile, looking at viewer, holding a black clipboard against her body with her left arm, "
           "right hand held out to her side palm up presenting something, pink ribbon bow at the collar, ")


def generate(icon: str, seed: int) -> Path:
    positive = STYLE + ICONS[icon]
    wf = comfy.graph(positive, NEGATIVE, seed, "uiart_%s_%d" % (icon, seed), 512, 512, False)
    return comfy.run(wf, OUT / ("%s_%d.png" % (icon, seed)), {"icon": icon, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8},
                                                             "positive": positive, "negative": NEGATIVE})


def generate_present(seed: int) -> Path:
    positive = comfy.CHARACTER + comfy.HAIRPIN + PRESENT + comfy.FRAMING
    wf = comfy.graph(positive, comfy.NEGATIVE, seed, "rikka_present_%d" % seed, 832, 1216, True)
    return comfy.run(wf, comfy.OUT / ("present_%d.png" % seed), {"expression": "present", "seed": seed, "positive": positive,
                                                                "negative": comfy.NEGATIVE, "loras": {"Koharu-Koharu-epoch100": 0.8, "anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 9401
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    if args[:1] == ["--present"]:
        for s in args[1:]:
            print(generate_present(int(s)))
        sys.exit(0)
    for icon in (args or list(ICONS)):
        print(generate(icon, seed))
