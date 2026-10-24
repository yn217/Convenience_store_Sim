extends RefCounted
## Issue #128: baskets (several items per visit). Covers the single-item compatibility (golden values from the
## pre-basket model), the basket draw, determinism, save/load replay with baskets, the v1 save migration, the
## checkout time and the balance target (units, revenue and occupancy against the old model).

const Run := preload("res://tests/support/basket_run.gd")
const V1_SAVE := "res://tests/data/savegame_v1_mid_day.json"
const SEED_ARRIVALS := 1234

## The pre-basket model (main before #128) on the sample layout, base 100, four days, fixed seeds.
## Re-run with basket_size forced to 1 and the old checkout time (30 s, no per-item time) it must match exactly.
const OLD_UNITS := [93, 84, 71, 75]
const OLD_REVENUE := [14705, 13410, 11490, 12280]
const OLD_CASH := 3345975
const OLD_TX := 705
const OLD_RNG := {"arrivals": 3510528978, "purchases": 3942537060, "visuals": 9012, "events": 345678}


func _single_item_state() -> GameState:
	return Run.new_state(100.0, {"basket_size_forced": 1, "checkout_base_game_seconds": 30, "checkout_per_item_game_seconds": 0})


## Compatibility (issue #128 requirement 1): one item per visit, the old visitors and the old checkout time give
## the old numbers, draw for draw. Only the basket draw and the per-item checkout time are new, and both are off here.
func test_single_item_visits_reproduce_the_pre_basket_model(t, _tree) -> void:
	var s := _single_item_state()
	var cmds := Run.place_layout(s)
	var r := Run.run_days(s, cmds, 4)
	t.eq(r["units"], OLD_UNITS, "units per day")
	t.eq(r["revenue"], OLD_REVENUE, "revenue per day")
	t.eq(s.cash_yen, OLD_CASH, "cash")
	t.eq(s.ledger.transactions.size(), OLD_TX, "ledger rows")
	for k in OLD_RNG:
		t.eq(int(s.rng_states[k]), OLD_RNG[k], "rng %s" % k)


func test_forced_single_item_consumes_no_basket_draw(t, _tree) -> void:
	var rng := Lcg32.new(SEED_ARRIVALS)
	var before := rng.state
	t.eq(BasketModel.draw_size(rng, {"basket_size_forced": 1, "basket_size_distribution": [{"basket_size": 4, "weight": 1}]}), 1)
	t.eq(rng.state, before, "no draw when forced")
	t.eq(BasketModel.draw_size(rng, {}), 1, "no distribution means one item")
	t.eq(rng.state, before, "and no draw")


## The distribution 1:40 2:35 3:20 4:5 (balance) over a long fixed-seed run, and the same seed gives the same sizes.
func test_basket_sizes_follow_the_balance_distribution(t, _tree) -> void:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var counts := {1: 0, 2: 0, 3: 0, 4: 0}
	var rng := Lcg32.new(SEED_ARRIVALS)
	var again := Lcg32.new(SEED_ARRIVALS)
	var same := true
	for i in 4000:
		var size := BasketModel.draw_size(rng, balance)
		counts[size] += 1
		same = same and size == BasketModel.draw_size(again, balance)
	t.ok(same, "same seed, same sizes")
	var want := {1: 0.40, 2: 0.35, 3: 0.20, 4: 0.05}
	for k in want:
		t.ok(absf(float(counts[k]) / 4000.0 - want[k]) < 0.03, "size %d share %.3f near %.2f" % [k, float(counts[k]) / 4000.0, want[k]])
	t.ok(absf(BasketModel.mean_size(balance) - 1.9) < 0.01, "mean basket about 1.9 items")


func test_checkout_takes_sixty_seconds_plus_twenty_per_item(t, _tree) -> void:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	t.eq(BasketModel.checkout_seconds(balance, 1), 80, "60 + 20 game seconds for one item (#117 v2)")
	t.eq(BasketModel.checkout_seconds(balance, 3), 120, "60 + 3 x 20 for three items")
	t.eq(BasketModel.checkout_seconds({"checkout_base_game_seconds": 30, "checkout_per_item_game_seconds": 0}, 4), 30, "the single-item override keeps 30 s")


## Determinism with baskets: the same run twice gives the same fingerprint; a save taken while customers carry
## several reservations, loaded and played on, ends in the same state as the run that never stopped.
func test_basket_run_is_deterministic_and_save_replay_matches(t, _tree) -> void:
	var a := Run.new_state(300.0)
	var cmds_a := Run.place_layout(a)
	Run.restock(a, cmds_a, 0)
	cmds_a.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner_a := SimulationRunner.new(a)
	var multi := false
	var guard := 0
	while not multi and guard < 20000:   # run until someone holds two items at once (a mid-basket moment)
		runner_a._run_step()
		for c in a.customers:
			multi = multi or (c["reservation_ids"] as Array).size() >= 2
		guard += 1
	t.ok(multi, "a basket with two reserved items occurs on this seed (step %d)" % guard)
	var saved := SaveGame.to_dict(a, "replay", "2026-10-24T00:00:00Z")
	var loaded := SaveGame.from_dict(JSON.parse_string(JSON.stringify(saved)), a.balance.duplicate(true), a.fixtures, a.products)
	t.ok(loaded["ok"], "the mid-basket save loads: %s" % str(loaded["errors"]))
	if not loaded["ok"]:
		return
	var b: GameState = loaded["state"]
	var runner_b := SimulationRunner.new(b)
	for i in 1500:
		runner_a._run_step()
		runner_b._run_step()
	t.eq(Run.fingerprint(b), Run.fingerprint(a), "loaded and uninterrupted runs agree after 1500 more steps")
	var c := Run.new_state(300.0)
	var cmds_c := Run.place_layout(c)
	Run.restock(c, cmds_c, 0)
	cmds_c.execute({"command_id": "open", "kind": &"START_BUSINESS"})
	var runner_c := SimulationRunner.new(c)
	for i in guard + 1500:
		runner_c._run_step()
	t.eq(Run.fingerprint(c), Run.fingerprint(a), "a fresh run with the same seeds is identical")


## Schema 1 saves (before #128) load as basket_size 1: their customers hold at most one reservation and no wishes.
func test_schema_one_save_loads_as_single_item_baskets(t, _tree) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(V1_SAVE))
	t.eq(int(data["schema_version"]), 1, "fixture is a schema 1 save")
	t.ok(not (data["customers"] as Array).is_empty(), "fixture has customers mid-visit")
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance/mvp_v1.json"))
	var fx := FixtureCatalog.from_json_text(FileAccess.get_file_as_string("res://data/fixtures/mvp_v1.json"))
	var pr := ProductCatalog.from_json_text(FileAccess.get_file_as_string("res://data/products/mvp_v1.json"))
	var r := SaveGame.from_dict(data, balance, fx, pr)
	t.ok(r["ok"], "schema 1 loads: %s" % str(r["errors"]))
	if not r["ok"]:
		return
	var s: GameState = r["state"]
	t.ok(not s.customers.is_empty(), "customers restored")
	for c in s.customers:
		t.eq(int(c["basket_size"]), 1, "%s basket_size 1" % c["customer_id"])
		t.ok((c["wishes"] as Array).is_empty(), "%s has no wishes" % c["customer_id"])
		t.ok((c["reservation_ids"] as Array).size() <= 1, "%s holds at most one reservation" % c["customer_id"])
	var again := SaveGame.to_dict(s, "migrated", "2026-10-24T00:00:00Z")
	t.eq(int(again["schema_version"]), SaveGame.SCHEMA_VERSION, "re-saved as the current schema")
	t.eq(int(again["customers"][0]["basket_size"]), 1, "re-saved customers carry basket_size")
	var bad = JSON.parse_string(JSON.stringify(data))
	bad["customers"][0]["basket_size"] = 5
	t.ok(not SaveGame.from_dict(bad, balance, fx, pr)["ok"], "basket_size outside 1..4 is rejected")


## Balance target (issue #128 requirement 3): with base visitors halved and baskets on, units sold and revenue per
## day stay within 10% of the old single-item model over the same fixed-seed days, and the store holds fewer
## customers at the same time. Both runs use the same sample layout, stock and seeds.
func test_halved_visitors_with_baskets_keep_units_and_revenue(t, _tree) -> void:
	var old_state := _single_item_state()
	var old := Run.run_days(old_state, Run.place_layout(old_state), 3)
	var new_state := Run.new_state(50.0)
	var new := Run.run_days(new_state, Run.place_layout(new_state), 3)
	var old_units := _sum(old["units"])
	var new_units := _sum(new["units"])
	var old_rev := _sum(old["revenue"])
	var new_rev := _sum(new["revenue"])
	print("BALANCE units old=%d new=%d revenue old=%d new=%d occupancy old=%.3f new=%.3f p95 old=%d new=%d peak old=%d new=%d buyers old=%d new=%d visitors old=%d new=%d" % [
		old_units, new_units, old_rev, new_rev, old["occupancy"], new["occupancy"], old["p95"], new["p95"], old["peak"], new["peak"],
		_sum(old["buyers"]), _sum(new["buyers"]), _sum(old["visitors"]), _sum(new["visitors"])])
	t.ok(absf(float(new_units) / float(old_units) - 1.0) <= 0.10, "units within 10%%: %d vs %d" % [new_units, old_units])
	t.ok(absf(float(new_rev) / float(old_rev) - 1.0) <= 0.10, "revenue within 10%%: %d vs %d" % [new_rev, old_rev])
	t.ok(float(new["occupancy"]) < float(old["occupancy"]), "fewer customers in the store on average: %.3f < %.3f" % [new["occupancy"], old["occupancy"]])
	t.ok(int(new["p95"]) <= int(old["p95"]), "busy-time customers (95th percentile of steps) do not rise: %d <= %d" % [new["p95"], old["p95"]])
	t.ok(int(new["peak"]) <= int(old["peak"]), "peak simultaneous customers do not rise: %d <= %d" % [new["peak"], old["peak"]])


func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += int(v)
	return total
