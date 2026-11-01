extends RefCounted
## Issue #141: the customer's mood — read off the visit (sold-out wishes, over-budget items, impulse and deal buys,
## time in the line, giving up), shown on the customer panel and summed up as the day's satisfaction. It changes no
## decision of the customer.

const Run := preload("res://tests/support/basket_run.gd")


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
