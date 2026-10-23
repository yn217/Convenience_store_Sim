extends RefCounted
## UI Phase 4: the notification policy (priority, limit, merge, durations), the level table, the merged texts and
## the one-pop-up-per-register sales rule. Pure functions and a plain object; no scene needed.


func _text(amount: int, count: int) -> String:
	return "件%d/%d" % [amount, count]


func test_levels_follow_the_cue_table_and_priority(t, _tree) -> void:
	t.eq(CueText.level_of("expiry_notice", "important"), "warning")
	t.eq(CueText.level_of("low_stock_notice", "normal"), "warning")
	t.eq(CueText.level_of("milestone_celebrate", "important"), "achievement")
	t.eq(CueText.level_of("daily_recap", "important"), "info")
	t.eq(CueText.level_of("brand_new_cue", "critical"), "error", "an unknown critical cue is an error")
	t.eq(CueText.level_of("brand_new_cue", "ambient"), "info")
	t.ok(NotificationPolicy.rank_of("error") > NotificationPolicy.rank_of("warning"))
	t.ok(NotificationPolicy.rank_of("warning") > NotificationPolicy.rank_of("achievement"))
	t.ok(NotificationPolicy.rank_of("achievement") > NotificationPolicy.rank_of("info"))


func test_durations_by_level_and_errors_stay(t, _tree) -> void:
	var p := NotificationPolicy.new()
	p.offer("a", "info", 1, Callable(self, "_text"))
	p.offer("b", "achievement", 1, Callable(self, "_text"))
	p.offer("c", "warning", 1, Callable(self, "_text"))
	p.advance(2.9)
	t.eq(p.items.size(), 3, "nothing is gone before 3 s")
	p.advance(0.2)   # 3.1 s: info (3 s) is gone, achievement (4 s) and warning (6 s) are not
	t.eq(p.items.size(), 2)
	t.eq(p.items[0]["level"], "achievement")
	p.advance(1.0)   # 4.1 s: achievement gone
	t.eq(p.items.size(), 1)
	t.eq(p.items[0]["level"], "warning")
	p.advance(2.0)   # 6.1 s: warning gone
	t.eq(p.items.size(), 0)
	p.offer("e", "error", 1, Callable(self, "_text"))
	p.advance(10000.0)
	t.eq(p.items.size(), 1, "an error stays until it is dismissed")
	p.dismiss(p.items[0])
	t.eq(p.items.size(), 0, "dismissed")


func test_limit_of_three_visible_and_priority_wins(t, _tree) -> void:
	var p := NotificationPolicy.new()
	p.offer("e1", "error", 1, Callable(self, "_text"))
	p.offer("w1", "warning", 1, Callable(self, "_text"))
	p.offer("i1", "info", 1, Callable(self, "_text"))
	t.eq(p.items.size(), 3)
	# A fourth info notice: the lowest rank goes, and on a tie the oldest of it (i1).
	p.offer("i2", "info", 1, Callable(self, "_text"))
	var keys: Array = p.items.map(func(x): return x["key"])
	t.eq(keys, ["e1", "w1", "i2"], "never more than three, the oldest info goes: %s" % str(keys))
	# A warning takes the place of the remaining info; the errors and the warning stay.
	p.offer("w2", "warning", 1, Callable(self, "_text"))
	keys = p.items.map(func(x): return x["key"])
	t.eq(keys, ["e1", "w1", "w2"], "the warning comes in: %s" % str(keys))
	# An info notice cannot push out the warnings or the error.
	p.offer("i3", "info", 1, Callable(self, "_text"))
	keys = p.items.map(func(x): return x["key"])
	t.eq(keys, ["e1", "w1", "w2"], "a new info is the one dropped: %s" % str(keys))


func test_same_kind_merges_into_one_with_totals(t, _tree) -> void:
	var p := NotificationPolicy.new()
	var first := p.offer("expiry_notice", "warning", 3, Callable(self, "_text"))
	var second := p.offer("expiry_notice", "warning", 4, Callable(self, "_text"))
	t.eq(p.items.size(), 1, "one toast for the kind")
	t.ok(is_same(first, second), "the merged notice is the same toast")
	t.eq(second["amount"], 7)
	t.eq(second["count"], 2)
	t.eq(second["text"], "件7/2", "the text is rebuilt with the totals")


func test_merge_window_is_measured_from_the_first_notice(t, _tree) -> void:
	var p := NotificationPolicy.new()
	p.offer("expiry_notice", "warning", 3, Callable(self, "_text"))
	p.advance(4.0)
	p.offer("expiry_notice", "warning", 1, Callable(self, "_text"))   # 4 s after the first: merges
	t.eq(p.items.size(), 1)
	t.eq(p.items[0]["count"], 2)
	p.advance(4.5)   # the toast is still shown (4.5 s since the merge), but 8.5 s since the first notice
	p.offer("expiry_notice", "warning", 1, Callable(self, "_text"))
	t.eq(p.items.size(), 2, "past the window the same kind starts a new toast")
	t.eq(p.items[1]["count"], 1)


func test_different_kinds_do_not_merge(t, _tree) -> void:
	var p := NotificationPolicy.new()
	p.offer("expiry_notice", "warning", 3, Callable(self, "_text"))
	p.offer("long_queue", "warning", 1, Callable(self, "_text"))
	t.eq(p.items.size(), 2)


func test_expiry_text_for_merged_and_single(t, _tree) -> void:
	t.eq(CueText.toast_text("expiry_notice", {"qty": 3, "count": 1}), "期限切れの商品を廃棄しました（3個）")
	t.eq(CueText.toast_text("expiry_notice", {"qty": 7, "count": 2}), "期限切れの商品を廃棄しました（計7個）")
	t.eq(CueText.toast_text("low_stock_notice", {"count": 3}, "棚"), "残りわずか: 3 件の棚")


func test_sales_share_one_pop_up_per_register(t, _tree) -> void:
	var sales: Array[Dictionary] = []
	NotificationPolicy.add_sale(sales, "reg_a", 210)
	NotificationPolicy.add_sale(sales, "reg_a", 240)   # within 0.3 s of the first
	t.eq(sales.size(), 1, "combined into one pop-up")
	t.eq(sales[0]["text"], "+¥450 ×2")
	NotificationPolicy.add_sale(sales, "reg_b", 100)
	t.eq(sales.size(), 2, "another register gets its own")
	sales[0]["age"] = 0.5
	NotificationPolicy.add_sale(sales, "reg_a", 300)   # too late to combine: replaces the old pop-up
	t.eq(sales.size(), 2, "still one per register")
	t.eq(sales[1]["text"], "+¥300", "the newer sale shows alone")
	t.eq(NotificationPolicy.sale_text(1234, 1), "+¥1,234")
