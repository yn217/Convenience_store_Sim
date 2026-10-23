extends RefCounted
## Selected-fixture card (mockup A): the pure formatting behind the rows.

const Card := preload("res://scripts/presentation/fixture_card.gd")


func _shelf() -> Dictionary:
	return {"display_name": "テスト棚", "placement_cost_yen": 120000, "footprint": {"w": 1, "h": 2},
		"capacity_units": 180, "shelf_slots": [{"slot_id": "row0", "capacity_units": 90}, {"slot_id": "row1", "capacity_units": 90}]}


func test_price_line_shows_price_and_footprint(t, _tree) -> void:
	t.eq(Card.price_line(_shelf()), "¥120,000 ・ 1×2")
	t.eq(Card.price_line({"placement_cost_yen": 90000, "footprint": {"w": 2, "h": 1}}), "¥90,000 ・ 2×1")


func test_capacity_sums_the_slots(t, _tree) -> void:
	t.eq(Card.capacity(_shelf()), 180)
	t.eq(Card.capacity({"capacity_units": 0, "shelf_slots": []}), 0, "a register holds no stock")
	t.eq(Card.capacity({"capacity_units": 12, "shelf_slots": []}), 12, "no slots: the fixture's own capacity")


func test_rows_stock_and_sales_shares(t, _tree) -> void:
	var rows := Card.rows(_shelf(), {"row0": 70, "row1": 70}, {"revenue_yen": 250, "gross_profit_yen": 100}, {"revenue_yen": 1000, "gross_profit_yen": 400})
	t.eq(rows.size(), 3)
	t.eq(rows[0]["label"], "在庫数")
	t.eq(rows[0]["value_text"], "140 / 180")
	t.ok(absf(float(rows[0]["ratio"]) - 140.0 / 180.0) < 0.0001, "stock ratio is units over capacity")
	t.eq(rows[1]["label"], "本日の売上")
	t.eq(rows[1]["value_text"], "¥250")
	t.eq(rows[1]["ratio"], 0.25, "sales share of the store today")
	t.eq(rows[2]["label"], "本日の粗利")
	t.eq(rows[2]["value_text"], "¥100")
	t.eq(rows[2]["ratio"], 0.25)


func test_rows_clamp_and_handle_empty_store(t, _tree) -> void:
	var rows := Card.rows(_shelf(), {"row0": 500}, {"revenue_yen": 0, "gross_profit_yen": 0}, {})
	t.eq(rows[0]["ratio"], 1.0, "overfull shelf clamps to a full bar")
	t.eq(rows[0]["value_text"], "500 / 180", "the number is still the truth")
	t.eq(rows[1]["ratio"], 0.0, "no sales today: empty bar")
	t.eq(rows[2]["value_text"], "¥0")


func test_register_without_shelves(t, _tree) -> void:
	var rows := Card.rows({"placement_cost_yen": 90000, "footprint": {"w": 1, "h": 2}, "capacity_units": 0, "shelf_slots": []}, {}, {"revenue_yen": 0, "gross_profit_yen": 0}, {})
	t.eq(rows[0]["value_text"], "棚なし")
	t.eq(rows[0]["ratio"], 0.0)


func test_share_is_clamped(t, _tree) -> void:
	t.eq(Card.share(-50, 100), 0.0)
	t.eq(Card.share(300, 100), 1.0)
	t.eq(Card.share(10, 0), 0.0)
