extends RefCounted
## Issue #136 phase 1: media advertising — booking and cancelling, the daily charge (once per day, no debt), the effect
## stock (ramp, peak, fade), the caps, hours and category pull, television's reputation, more visitors, the save.

const Run := preload("res://tests/support/basket_run.gd")


func _cmd(s: GameState, kind: StringName, payload: Dictionary) -> CommandResult:
	var c := {"command_id": "mk_%d_%s" % [s.applied_command_ids.size(), kind], "kind": kind}
	c.merge(payload)
	return GameCommands.new(s).execute(c)


func test_media_data(t, _tree) -> void:
	var ids: Array = Marketing.data()["media"].map(func(m): return m["medium"])
	t.eq(ids, ["newspaper", "radio", "web_ads", "television"], "four media")
	for m in Marketing.data()["media"]:
		t.ok(int(m["min_days"]) <= int(m["default_days"]) and int(m["default_days"]) <= int(m["max_days"]), m["medium"] + ": days")
		t.ok(float(m["carry"]) < 1.0 and float(m["max_lift"]) > 0.0, m["medium"] + ": fades and lifts")
	t.eq(int(Marketing.medium("television")["setup_cost_yen"]), 10000, "playable television cost (decided 2026-10-27)")


func test_booking_and_cancelling(t, _tree) -> void:
	var s := Run.new_state(100.0)
	var cash := s.cash_yen
	t.ok(_cmd(s, &"BOOK_CAMPAIGN", {"medium": "newspaper", "days": 2}).ok, "newspaper booked")
	t.eq(s.cash_yen, cash - 1000, "the setup cost is paid at once")
	var c: Dictionary = s.campaigns[0]
	t.eq([c["start_day"], c["end_day"]], [1, 2], "after its lead day, for two days")
	t.ok(not _cmd(s, &"BOOK_CAMPAIGN", {"medium": "newspaper", "days": 9}).ok, "days out of range")
	t.ok(not _cmd(s, &"BOOK_CAMPAIGN", {"medium": "web_ads", "days": 2, "daily_budget_yen": 50}).ok, "budget out of range")
	t.ok(_cmd(s, &"CANCEL_CAMPAIGN", {"campaign_id": c["campaign_id"]}).ok, "cancelled before the start")
	t.eq(s.cash_yen, cash - 1000, "no refund of the setup cost")
	for i in 4:
		t.ok(_cmd(s, &"BOOK_CAMPAIGN", {"medium": "web_ads", "days": 2, "daily_budget_yen": 1000}).ok, "web ads %d" % i)
	var r := _cmd(s, &"BOOK_CAMPAIGN", {"medium": "radio", "days": 3})
	t.ok(not r.ok and r.message_key == &"too_many_campaigns", "at most four at once")
	s.day = 1
	r = _cmd(s, &"CANCEL_CAMPAIGN", {"campaign_id": s.campaigns[1]["campaign_id"]})
	t.ok(not r.ok and r.message_key == &"campaign_started", "a started campaign cannot be cancelled")


## The stock ramps up over the airing days and fades after; each day is charged once; an unpaid day does nothing.
func test_daily_charge_and_effect_stock(t, _tree) -> void:
	var s := Run.new_state(100.0)
	_cmd(s, &"BOOK_CAMPAIGN", {"medium": "radio", "days": 3})   # lead 2: days 2..4
	var lifts: Array = []
	for d in range(0, 8):
		s.day = d
		BusinessService.charge_day(s, d, true)
		BusinessService.charge_day(s, d, true)   # a reload or re-open: nothing twice
		lifts.append(snappedf(Marketing.campaign_lift(s.campaigns[0], 8), 0.001))
	var rows := s.ledger.transactions.filter(func(tx): return tx["event_type"] == "AD_MEDIA")
	t.eq(rows.size(), 3, "three airing days, three charges")
	t.eq(lifts[0], 0.0, "nothing before the start")
	t.ok(lifts[2] > 0.0 and lifts[3] > lifts[2] and lifts[4] > lifts[3], "ramps up while airing: %s" % str(lifts))
	t.ok(lifts[5] < lifts[4] and lifts[6] < lifts[5], "fades after the end")
	t.eq(Marketing.campaign_lift(s.campaigns[0], 12), 0.0, "radio works only in the commute hours")
	var poor := Run.new_state(100.0)
	_cmd(poor, &"BOOK_CAMPAIGN", {"medium": "newspaper", "days": 1})
	poor.ledger.cash_yen = 100
	poor.day = 1
	BusinessService.charge_day(poor, 1, true)
	t.eq(poor.campaigns[0]["paid_days"], [], "not enough cash: the airing day is not paid")
	t.eq(float(poor.campaigns[0]["stock"]), 0.0, "and has no effect")
	t.ok(poor.ledger.cash_yen >= 0, "no debt from advertising")


func test_caps_and_pulls(t, _tree) -> void:
	var s := Run.new_state(100.0)
	t.eq(Marketing.ad_factor(s, 9, 1.4, 1.0), 1.4, "no campaigns: the tier's multiplier exactly")
	for m in ["television", "newspaper", "web_ads", "radio"]:
		_cmd(s, &"BOOK_CAMPAIGN", {"medium": m, "days": Marketing.medium(m)["max_days"], "daily_budget_yen": 3000, "category": "dessert"})
	for c in s.campaigns:
		c["stock"] = 10.0
	t.eq(Marketing.ad_factor(s, 8, 1.4, 1.0), 1.6, "the pool stops at +60%")
	t.ok(absf(Marketing.ad_factor(s, 8, 1.4, 1.4) - 2.0 / 1.4) < 0.0001, "with the event, the total stays at 2.0")
	t.ok(Marketing.category_multiplier(s, "dessert") > 1.25, "web ads pull their category")
	t.ok(Marketing.category_multiplier(s, "rice_ball") > 1.05, "the newspaper pulls onigiri")
	t.eq(Marketing.category_multiplier(s, "snack"), 1.0, "and nothing else")
	var tv := Run.new_state(100.0)
	_cmd(tv, &"BOOK_CAMPAIGN", {"medium": "television", "days": 5})
	var rep := tv.reputation
	for d in range(0, 12):
		tv.day = d
		BusinessService.charge_day(tv, d, true)
	t.eq(tv.reputation, rep + 3, "television: +1 per airing day, at most +3")


## In a running store a campaign brings more visitors, its costs show as advertising, and it survives a save.
func test_a_campaign_brings_visitors(t, _tree) -> void:
	var seen := {}
	for with_ad in [false, true]:
		var s := Run.new_state(300.0)
		var cmds := Run.place_layout(s)
		if with_ad:
			cmds.execute({"command_id": "ad", "kind": &"BOOK_CAMPAIGN", "medium": "web_ads", "days": 3, "daily_budget_yen": 3000})
		Run.run_days(s, cmds, 3)
		seen[with_ad] = int(s.daily_reports[1]["visitors"]) + int(s.daily_reports[2]["visitors"])
		if with_ad:
			t.ok(int(s.daily_reports[1]["advertising_yen"]) >= 3000, "the airing day's cost is advertising")
			t.eq(SaveGame.semantic_errors(s), [] as Array[String], "the ledger stays consistent")
			var saved := SaveGame.to_dict(s, "mk", "2026-10-27T00:00:00Z")
			var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
			t.ok(lr["ok"], str(lr["errors"]))
			t.eq((lr["state"] as GameState).campaigns, s.campaigns, "campaigns survive a save")
	t.ok(int(seen[true]) > int(seen[false]), "more visitors on the airing days (%d > %d)" % [seen[true], seen[false]])
