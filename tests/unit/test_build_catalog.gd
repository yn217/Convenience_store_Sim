extends RefCounted
## Build catalog (mockup 建設 什器カタログ): tab grouping from the fixture definitions, the affordability rule and the
## column count. The card layout itself is covered by the scene tests.

const Cat := preload("res://scripts/presentation/build_catalog.gd")
const FIXTURES := "res://data/fixtures/mvp_v1.json"


func _catalog() -> FixtureCatalog:
	return FixtureCatalog.from_json_text(FileAccess.get_file_as_string(FIXTURES))


func test_mvp_fixtures_split_into_four_tabs(t, _tree) -> void:
	var groups := Cat.group(_catalog())
	t.eq(groups[Cat.ALL].size(), 26, "すべて holds all twenty-six types")
	t.eq(groups[Cat.SHELF], ["shelf_general", "shelf_onigiri", "shelf_noodle", "shelf_bread", "shelf_snack", "shelf_goods"], "棚: the six shelves, in data order (goods, #133)")
	t.eq(groups[Cat.COLD], ["fridge_drink", "fridge_dessert", "freezer_ice", "fridge_daily"], "冷蔵・冷凍: the four cases (daily fresh, #147)")
	t.eq(groups[Cat.COUNTER], ["register_basic", "warmer_oden", "coffee_machine", "soft_serve_machine", "frappe_blender", "bakery_oven", "pizza_oven"], "カウンター: the register, the oden warmer, the coffee machine, the soft serve / frappé machines and the ovens")
	t.eq(groups[Cat.SERVICE], ["atm", "copier", "staff_room_s", "staff_room_m", "staff_room_l", "capsule_toy_1", "capsule_toy_3", "capsule_toy_5", "eat_in_counter"], "設備: the ATM, the copier, the staff rooms, the capsule machines and the eat-in counter")


func test_every_type_is_in_exactly_one_category(t, _tree) -> void:
	var groups := Cat.group(_catalog())
	var count: int = groups[Cat.SHELF].size() + groups[Cat.COLD].size() + groups[Cat.COUNTER].size() + groups[Cat.SERVICE].size()
	t.eq(count, int(groups[Cat.ALL].size()), "the four tabs partition the full list")


func test_category_rule_from_allowed_categories(t, _tree) -> void:
	t.eq(Cat.category_of({"allowed_categories": ["drink"]}), Cat.COLD, "a drink case is cold")
	t.eq(Cat.category_of({"allowed_categories": ["snack", "dessert"]}), Cat.COLD, "any cold product makes it cold")
	t.eq(Cat.category_of({"allowed_categories": ["oden"]}), Cat.COUNTER, "an oden-only warmer is a counter item")
	t.eq(Cat.category_of({"allowed_categories": [], "register_queue_max_tiles": 3}), Cat.COUNTER, "the register (no products) is a counter item")
	t.eq(Cat.category_of({"allowed_categories": []}), Cat.SERVICE, "no products and no register queue (ATM, copier) is a service item")
	t.eq(Cat.category_of({"allowed_categories": ["bread"]}), Cat.SHELF, "a dry-goods shelf is 棚")


func test_affordable_at_or_above_the_price_only(t, _tree) -> void:
	t.ok(Cat.affordable(90000, 90000), "exactly the price is affordable")
	t.ok(Cat.affordable(90000, 3836680), "well above the price is affordable")
	t.ok(not Cat.affordable(130000, 129999), "one yen short is not affordable")
	t.ok(not Cat.affordable(40000, 0), "no cash affords nothing")


func test_every_type_gets_a_large_thumbnail(t, _tree) -> void:
	for type_id in _catalog().types:
		var tex := Cat.thumbnail(type_id)
		t.ok(tex != null, "catalog thumbnail for " + type_id)
		if tex == null:
			continue
		t.eq(tex.get_size(), Vector2(Cat.THUMB_PIXELS), "source is 192x128: " + type_id)
		t.ok(is_same(tex, Cat.thumbnail(type_id)), "cached per type: " + type_id)
