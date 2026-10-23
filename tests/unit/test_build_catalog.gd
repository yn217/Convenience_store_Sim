extends RefCounted
## Build catalog (mockup 建設 什器カタログ): tab grouping from the fixture definitions, the affordability rule and the
## column count. The card layout itself is covered by the scene tests.

const Cat := preload("res://scripts/presentation/build_catalog.gd")
const FIXTURES := "res://data/fixtures/mvp_v1.json"


func _catalog() -> FixtureCatalog:
	return FixtureCatalog.from_json_text(FileAccess.get_file_as_string(FIXTURES))


func test_mvp_fixtures_split_into_three_tabs(t, _tree) -> void:
	var groups := Cat.group(_catalog())
	t.eq(groups[Cat.ALL].size(), 10, "すべて holds all ten types")
	t.eq(groups[Cat.SHELF], ["shelf_general", "shelf_onigiri", "shelf_noodle", "shelf_bread", "shelf_snack"], "棚: the five shelves, in data order")
	t.eq(groups[Cat.COLD], ["fridge_drink", "fridge_dessert", "freezer_ice"], "冷蔵・冷凍: the three cases")
	t.eq(groups[Cat.COUNTER], ["register_basic", "warmer_oden"], "カウンター: the register and the oden warmer")


func test_every_type_is_in_exactly_one_category(t, _tree) -> void:
	var groups := Cat.group(_catalog())
	var count: int = groups[Cat.SHELF].size() + groups[Cat.COLD].size() + groups[Cat.COUNTER].size()
	t.eq(count, int(groups[Cat.ALL].size()), "the three tabs partition the full list")


func test_category_rule_from_allowed_categories(t, _tree) -> void:
	t.eq(Cat.category_of({"allowed_categories": ["drink"]}), Cat.COLD, "a drink case is cold")
	t.eq(Cat.category_of({"allowed_categories": ["snack", "dessert"]}), Cat.COLD, "any cold product makes it cold")
	t.eq(Cat.category_of({"allowed_categories": ["oden"]}), Cat.COUNTER, "an oden-only warmer is a counter item")
	t.eq(Cat.category_of({"allowed_categories": []}), Cat.COUNTER, "no product category (register) is a counter item")
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
