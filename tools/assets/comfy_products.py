"""Product icons for the UI lists (発注・価格・棚の商品・売れ筋・吹き出し), in place of ProductIcons' code-drawn
placeholders: one illustration per SKU, a single item on white, rendered by the local ComfyUI (anima-style LoRA 0.8,
no text, no real brands). tools/assets/build_product_icons.py cuts them out to assets/ui/products/<sku_id>.png.
The in-store shelf drawing is not changed (#91).

    python tools/assets/comfy_products.py           # all; or sku ids; --seed N (default 9301)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import comfy_rikka as comfy  # noqa: E402

OUT = Path("assets/source/products")
STYLE = ("anima_style, cute product icon illustration, a single item, centered, whole item in frame, slight three-quarter "
         "view from the front, clean lineart, soft shading, plain pure white background, no text, no letters, no logo, ")
SKUS = {
    "rice_001": "a white triangle onigiri rice ball with a band of nori seaweed only along the bottom, orange salmon filling peeking out",
    "rice_002": "a white triangle onigiri rice ball with a band of nori seaweed only along the bottom, a red pickled plum on top",
    "rice_003": "a white triangle onigiri rice ball with a band of nori seaweed only along the bottom, tuna mayonnaise filling peeking out",
    "oden_001": "a thick round slice of simmered daikon radish in a small paper oden cup with broth",
    "oden_002": "a simmered brown boiled egg in a small paper oden cup with broth",
    "oden_003": "a thick dark grey rectangular konjac block with a criss-cross scored surface, in a small paper oden cup with broth",
    "noodle_001": "an instant cup noodle with a brown soy sauce coloured paper lid, plain package",
    "noodle_002": "an instant cup noodle with an orange miso coloured paper lid, plain package",
    "noodle_003": "an instant cup noodle with a pale blue salt ramen coloured paper lid, plain package",
    "bread_001": "a melon pan sweet bun with a crisp cookie crust and a grid pattern",
    "bread_002": "a golden flaky croissant",
    "bread_003": "a round anpan sweet bun with a few sesame seeds on top",
    "drink_001": "a 500ml plastic bottle of green tea with a plain green label",
    "drink_002": "a 500ml plastic bottle of soda with a plain red label and bubbles",
    "drink_003": "a 500ml plastic bottle of mineral water with a plain light blue label",
    "snack_001": "a bag of potato chips with a plain yellow package and a few chips beside it",
    "snack_002": "a bar of milk chocolate partly unwrapped from a plain brown wrapper",
    "snack_003": "a small bag of colourful gummy candies with a few gummies beside it, plain package",
    "dessert_001": "a custard pudding in a clear cup with caramel on top",
    "dessert_002": "a slice of baked cheesecake on a small paper tray",
    "dessert_003": "a fruit jelly in a clear cup with orange and grape pieces inside",
    "ice_001": "a vanilla ice cream cup with the lid open and a wooden spoon",
    "ice_002": "a chocolate coated ice cream bar on a stick",
    "ice_003": "a fruit popsicle ice bar with strawberry and orange colours on a stick",
    "bento_001": "a makunouchi bento box with rice, grilled fish, egg roll and vegetables in compartments",
    "bento_002": "a bento box with rice and japanese fried chicken karaage",
    "bento_003": "a nori bento box with rice covered in seaweed, a white fish fry and chikuwa tempura",
    "fresh_001": "a clear bag of cut salad vegetables, lettuce, cabbage and carrot",
    "fresh_002": "a white block of silken tofu in a clear plastic pack",
    "fresh_003": "a 1 litre paper carton of milk with a plain blue and white design",
    "coffee_001": "a small hot coffee in a white paper cup with a lid, a little steam",
    "coffee_002": "a medium iced coffee in a clear plastic cup with ice and a straw",
    "coffee_003": "a cafe latte in a paper cup with a lid",
    "capsule_001": "a round clear toy capsule holding a small cute animal mascot figure",
    "capsule_002": "a round clear plastic toy capsule, half pink and half clear, with a tiny salmon sushi figure clearly visible inside",
    "capsule_003": "a round clear toy capsule holding a small robot figure",
    "goods_001": "three pairs of colourful socks, navy, grey and white, fanned out side by side",
    "goods_002": "a plain white crew neck t-shirt undershirt laid flat",
    "goods_003": "a clear plastic vinyl umbrella, closed",
    "hyg_001": "a pack of white face masks in a plain package",
    "hyg_002": "a small box of adhesive bandages with a few plasters beside it, plain package",
    "hyg_003": "a pack of wet wipes with a plain blue flip lid",
    "soft_001": "a vanilla soft serve ice cream in a cone",
    "soft_002": "a vanilla and chocolate swirl soft serve ice cream in a cone",
    "soft_003": "a chocolate soft serve ice cream in a cone",
    "frappe_001": "a pink strawberry frappe in a clear cup with whipped cream and a straw",
    "frappe_002": "a green matcha frappe in a clear cup with whipped cream and a straw",
    "frappe_003": "a yellow mango frappe in a clear cup with whipped cream and a straw",
    "bake_001": "a freshly baked golden croissant, warm, on a small paper sheet",
    "bake_002": "a freshly baked melon pan sweet bun, warm, on a small paper sheet",
    "bake_003": "a freshly baked deep fried curry bread with crumb coating, on a small paper sheet",
    "pizza_001": "a whole margherita pizza with tomato, mozzarella and basil",
    "pizza_002": "a whole teriyaki chicken pizza with mayonnaise and seaweed flakes",
    "pizza_003": "a whole four cheese pizza, golden melted cheese",
    "cgoods_001": "a white mug with a cute round yellow chick mascot printed on it",
    "cgoods_002": "a round pin badge with a cute round yellow chick mascot",
    "cgoods_003": "a small flat square hand towel, light yellow, folded once, with a small round yellow chick mascot embroidered in one corner",
    "crane_001": "a cute cat plush toy",
    "crane_002": "a cute brown bear cushion plush",
    "crane_003": "a big cute white rabbit plush toy",
}
NEGATIVE = ("low quality, worst quality, blurry, text, letters, words, numbers, logo, brand name, watermark, people, person, "
            "hands, character, background scenery, table, multiple items, cropped")


def generate(sku: str, seed: int) -> Path:
    wf = comfy.graph(STYLE + SKUS[sku], NEGATIVE, seed, "product_%s_%d" % (sku, seed), 512, 512, False)
    return comfy.run(wf, OUT / ("%s_%d.png" % (sku, seed)), {"sku_id": sku, "seed": seed, "loras": {"anima-style-epoch35-lr5e5": 0.8},
                                                            "positive": STYLE + SKUS[sku], "negative": NEGATIVE})


if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 9301
    if "--seed" in args:
        i = args.index("--seed")
        seed = int(args[i + 1])
        del args[i:i + 2]
    for s in (args or list(SKUS)):
        print(generate(s, seed))
