"""Catalog photos for the fixtures that have no in-store art yet (the build catalog showed a grey box): one product
illustration per type, three-quarter view on white, rendered by the local ComfyUI (anima-style LoRA 0.8, no text,
no real brands). tools/assets/build_catalog_thumbs.py cuts them out to the catalog's 192x128 thumbnails. In-store art
for these types stays with the projection-calibrated fixture pipeline (#163 / #171).

    python tools/assets/comfy_catalog.py        # all; or type ids
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/catalog")
STYLE = ("anima_style, clean product illustration, single object, three-quarter view from above, isometric angle, "
         "japanese convenience store equipment, soft shading, plain pure white background, no text, no logo, ")
TYPES = {
    "staff_room_s": "a small staff break room seen from above with one locker, a small table and one chair, cutaway room",
    "staff_room_m": "a staff break room seen from above with lockers, a table with two chairs and a small fridge, cutaway room",
    "staff_room_l": "a large staff break room seen from above with many lockers, a table with four chairs, a sofa and a fridge, cutaway room",
    "fridge_daily": "an open refrigerated display case with vegetables, tofu packs and milk bottles on shelves",
    "coffee_machine": "a self-service coffee machine on a small counter with paper cups and lids",
    "capsule_toy_1": "one capsule toy vending machine with clear dome full of colorful capsules and a turning handle",
    "capsule_toy_3": "a row of three capsule toy vending machines with colorful capsules",
    "capsule_toy_5": "a row of five capsule toy vending machines stacked, colorful capsules",
    "shelf_goods": "a store shelf with daily goods: socks, umbrellas, tissues, masks and small character goods, plain packages",
    "soft_serve_machine": "a soft serve ice cream machine on a counter with cones",
    "frappe_blender": "a frappe blender machine on a small counter with a cup of iced frappe",
    "bakery_oven": "a bakery oven with a glass display case of fresh baked breads below",
    "pizza_oven": "a compact pizza oven with a pizza on a peel, on a counter",
    "eat_in_counter": "an eat-in counter by a window with three tall stools",
    "eat_in_table": "a small square eat-in table with four chairs",
    "crane_game": "a crane game machine, claw machine with plush toys inside a glass cabinet, bright lights",
}
NEGATIVE = "low quality, worst quality, blurry, text, letters, logo, brand name, watermark, people, person, hands, background scenery, floor shadow"


def generate(type_id: str, seed: int = 8101) -> Path:
    wf = comfy.graph(STYLE + TYPES[type_id], NEGATIVE, seed, "catalog_%s_%d" % (type_id, seed), 768, 512, False)
    return comfy.run(wf, OUT / ("%s_%d.png" % (type_id, seed)), {"type_id": type_id, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8}})


if __name__ == "__main__":
    for t in (sys.argv[1:] or list(TYPES)):
        print(generate(t))
