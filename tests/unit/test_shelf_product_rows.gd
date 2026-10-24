extends RefCounted
## #105 B4: the inspector lists the products on a shelf, one row per SKU, with the override price when one is set.

const Card := preload("res://scripts/presentation/fixture_card.gd")


func test_one_row_per_sku_in_slot_order(t, _tree) -> void:
	var rows := Card.shelf_product_rows({"s2": "snack_a", "s1": "snack_a", "s3": "drink_b"}, {}, null)
	t.eq(rows.size(), 2, "two SKUs on three slots")
	t.eq(rows[0]["sku_id"], "snack_a", "first slot's SKU comes first")
	t.eq(rows[0]["slots"], 2, "the SKU holds two slots")
	t.eq(rows[1]["sku_id"], "drink_b", "then the next SKU")
	t.eq(rows[1]["slots"], 1, "one slot")


func test_price_override_wins_over_the_default(t, _tree) -> void:
	var rows := Card.shelf_product_rows({"s1": "drink_b"}, {"drink_b": 99}, null)
	t.eq(rows[0]["price"], 99, "the player's price is shown")
	var plain := Card.shelf_product_rows({"s1": "drink_b"}, {}, null)
	t.eq(plain[0]["price"], 0, "no catalog and no override: the default is 0")


func test_empty_shelf_has_no_rows(t, _tree) -> void:
	t.ok(Card.shelf_product_rows({}, {}, null).is_empty(), "nothing on the shelf")
