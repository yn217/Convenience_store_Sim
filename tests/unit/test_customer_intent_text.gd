extends RefCounted
## Customer intent on screen (issues #15, #16, #23, #30): the pure presentation helpers that turn the read-only
## customer views into text and counts, and the sale pop-up text per product.


func test_customer_action_text_follows_phase_and_target(t, _tree) -> void:
	t.eq(OverlayModel.customer_action({"phase": "SELECT"}, ""), "商品を選択中")
	t.eq(OverlayModel.customer_action({"phase": "WALK_SHELF"}, "おにぎり棚"), "おにぎり棚へ移動中")
	t.eq(OverlayModel.customer_action({"phase": "WALK_SHELF"}, ""), "棚へ移動中", "no shelf name: a generic word, never an empty target")
	t.eq(OverlayModel.customer_action({"phase": "WALK_REGISTER"}, ""), "レジへ移動中")
	t.eq(OverlayModel.customer_action({"phase": "QUEUE", "queue_slot": 1}, ""), "会計待ち (2番目)")
	t.eq(OverlayModel.customer_action({"phase": "QUEUE", "queue_slot": 0}, ""), "会計待ち (1番目)")
	t.eq(OverlayModel.customer_action({"phase": "CHECKOUT"}, ""), "会計中")
	t.eq(OverlayModel.customer_action({"phase": "EXIT"}, ""), "退店中")
	t.ok(OverlayModel.customer_action({"phase": "WAIT_QUEUE"}, "").find("待ち") >= 0, "a full line says it waits")


func test_register_queues_count_waiting_and_checkout(t, _tree) -> void:
	var views := [
		{"phase": "CHECKOUT", "register_id": "fx_0009", "checkout_left": 14},
		{"phase": "QUEUE", "register_id": "fx_0009", "queue_slot": 0},
		{"phase": "WALK_REGISTER", "register_id": "fx_0009", "queue_slot": 1},
		{"phase": "WAIT_QUEUE", "register_id": "fx_0009", "queue_slot": -1},
		{"phase": "WALK_SHELF", "register_id": ""},          # not yet at a register
		{"phase": "EXIT", "register_id": "fx_0009"},         # leaving: not in line any more
		{"phase": "QUEUE", "register_id": "fx_0011", "queue_slot": 0},
	]
	var q := OverlayModel.register_queues(views)
	t.eq(int(q["fx_0009"]["waiting"]), 3, "walking to, queued and waiting customers count as waiting")
	t.eq(int(q["fx_0009"]["checkout"]), 1, "one at the till")
	t.eq(int(q["fx_0009"]["left"]), 14, "the till's time left comes from the view")
	t.eq(int(q["fx_0011"]["waiting"]), 1)
	t.eq(OverlayModel.queue_badge_text(3), "レジ待ち 3人")
	t.ok(not OverlayModel.register_queues([]).has("fx_0009"), "no customers, no register entries")


func test_estimated_wait_only_from_the_checkout_model(t, _tree) -> void:
	# 30 s per checkout: the one at the till has 14 s left, two are in line -> 14 + 2 * 30 = 74 s -> 2 minutes.
	t.eq(OverlayModel.estimated_wait_minutes({"waiting": 2, "checkout": 1, "left": 14}, 30), 2)
	t.eq(OverlayModel.estimated_wait_minutes({"waiting": 0, "checkout": 0, "left": 0}, 30), 0, "nobody: no wait")
	t.eq(OverlayModel.estimated_wait_minutes({"waiting": 2, "checkout": 0, "left": 0}, 0), -1, "no checkout duration in the model: not stated")
	t.eq(OverlayModel.register_info_text({"waiting": 2, "checkout": 1, "left": 14}, 2), "■ レジ 待ち2・会計中1 目安 約2分")
	t.eq(OverlayModel.register_info_text({"waiting": 0, "checkout": 0, "left": 0}, -1), "■ レジ 待ち0・会計中0", "an idle register states counts only")


func test_sale_pop_reads_product_and_price(t, _tree) -> void:
	var sales: Array = []
	var one := NotificationPolicy.add_sale(sales, "fx_0009", 150, "おにぎり")
	t.eq(one["text"], "おにぎり ¥150", "one sale: <商品名> ¥<price>")
	var same := NotificationPolicy.add_sale(sales, "fx_0009", 150, "おにぎり")
	t.eq(same["text"], "おにぎり ¥300 ×2", "a merged pop-up keeps the product and shows the total")
	var other := NotificationPolicy.add_sale(sales, "fx_0009", 120, "お茶")
	t.eq(other["text"], "+¥420 ×3", "mixed products fall back to the total")
	t.eq(NotificationPolicy.sale_text(1234, 1), "+¥1,234", "no product name: the old pop-up text")
	t.eq(NotificationPolicy.sale_label(150, 1, "おにぎり"), "おにぎり ¥150")
