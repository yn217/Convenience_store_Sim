extends RefCounted
## Issue #141: the customer's mood — read off the visit (sold-out wishes, over-budget items, impulse and deal buys,
## time in the line, giving up), shown on the customer panel and summed up as the day's satisfaction. It changes no
## decision of the customer.

const Run := preload("res://tests/support/basket_run.gd")


func test_what_moves_the_mood(t, _tree) -> void:
	t.eq(CustomerMood.of({}, 0), 70, "70 at the door")
	var log := [{"state": "stockout", "kind": "target"}, {"state": "taken", "kind": "impulse"}, {"state": "too_expensive", "kind": "target"}]
	t.eq(CustomerMood.of({"basket_log": log}, 0), 70 - 15 + 5 - 5, "sold out, impulse, over budget")
	t.eq(CustomerMood.of({"phase": "QUEUE", "queue_since": 1000}, 1000 + 6 * 60), 70 - 3 * 4, "6 minutes in the line: 4 past the first two")
	t.eq(CustomerMood.of({"waited_sec": 300}, 99999), 70 - 3 * 3, "the wait up to the till is kept")
	t.eq(CustomerMood.of({"outcome": "queue_timeout", "waited_sec": 120}, 0), 40, "giving up in the line")
	t.eq(CustomerMood.of({"coupon_used": true, "seat": Vector2i(1, 1)}, 0), 80, "a coupon and a seat")
	t.eq(CustomerMood.band(80), "満足")
	t.eq(CustomerMood.band(60), "ふつう")
	t.eq(CustomerMood.band(30), "不満")
	var lines := OverlayModel.customer_panel_lines({"customer_id": "c1", "purpose_name": "昼食", "mood": 45}, "")
	t.ok(lines.any(func(l): return String(l).contains("気分 45（不満）")), "on the customer panel: %s" % str(lines))


func test_the_days_satisfaction(t, _tree) -> void:
	var s := Run.new_state(200.0)
	var cmds := Run.place_layout(s)
	Run.run_days(s, cmds, 1)
	var r: Dictionary = s.daily_reports[0]
	t.ok(r.has("satisfaction") and int(r["satisfaction"]) >= 0 and int(r["satisfaction"]) <= 100, "the report carries the satisfaction: %s" % str(r.get("satisfaction")))
	t.ok(ReportController.summary_text(s.daily_reports).contains("満足度"), "and the daily report shows it")
	var saved := SaveGame.to_dict(s, "mood", "2026-10-28T00:00:00Z")
	var lr := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), s.balance.duplicate(true), s.fixtures, s.products)
	t.ok(lr["ok"], str(lr["errors"]))
	t.eq((lr["state"] as GameState).daily_reports[0].get("satisfaction"), r["satisfaction"], "it survives a save")
