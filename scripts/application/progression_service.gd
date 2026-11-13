class_name ProgressionService
extends RefCounted
## Tutorial steps, milestones and the daily challenge (15 §2-4, 6). Everything is judged from
## confirmed Domain data - fixtures, ledger rows, closed day reports, stock - never from clicks or
## from having opened a screen. Rewards are badges and notices only: nothing here moves cash,
## stock, prices or reputation. Each achievement is announced once; `progression_state` is saved,
## so a load never re-announces anything.
##
## evaluate() is cheap enough to run every frame: ledger rows are scanned incrementally.

const TUTORIAL_STEPS := 8
const CHALLENGES := {1: "challenge_sales_3", 2: "challenge_stock_2", 0: "challenge_no_waste"}
const SALES_GOAL := 3
const CATEGORY_GOAL := 2
const METRICS := [
	"total_sales_count", "daily_operating_profit_at_least", "total_customers_entered", "unique_categories_stocked",
	"fixtures_installed_count", "day_closed_count", "total_revenue_yen", "reputation_at_least",
]


## Parsed milestone list, or [] with problems reported through `errors`.
static func load_milestones(data, errors: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(data) != TYPE_ARRAY:
		errors.append("$: not_array")
		return out
	var seen := {}
	for i in data.size():
		var m = data[i]
		var path := "milestones[%d]" % i
		if typeof(m) != TYPE_DICTIONARY:
			errors.append("%s: not_object" % path)
			continue
		var errs := JsonCheck.key_errors(m, ["schema_version", "milestone_id", "name_ja", "metric", "threshold", "reward", "notice_cue_id"], [], path)
		errors.append_array(errs)
		if not errs.is_empty():
			continue
		if not JsonCheck.is_nonempty_string(m["milestone_id"]) or not String(m["milestone_id"]).begins_with("ms_"):
			errors.append("%s.milestone_id: invalid" % path)
		elif seen.has(m["milestone_id"]):
			errors.append("%s.milestone_id: duplicate_id" % path)
		seen[m["milestone_id"]] = true
		if not METRICS.has(m["metric"]):
			errors.append("%s.metric: unknown" % path)
		if not JsonCheck.is_int(m["threshold"]) or int(m["threshold"]) < 1:
			errors.append("%s.threshold: invalid" % path)
		if typeof(m["reward"]) != TYPE_DICTIONARY or m["reward"].get("kind") != "badge_only":
			errors.append("%s.reward: only badge_only is allowed" % path)
		if not JsonCheck.is_nonempty_string(m["name_ja"]):
			errors.append("%s.name_ja: empty" % path)
		if errors.is_empty():
			var copy: Dictionary = m.duplicate(true)
			copy["threshold"] = int(copy["threshold"])
			out.append(copy)
	return out


## Runs every rule once against the current state and returns the achievements that are new.
## The same events are queued in state.progression_events for the UI to announce.
static func evaluate(state: GameState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_scan(state)
	_tutorial(state, events)
	_milestones(state, events)
	_challenge(state, events)
	_rank(state, events)
	for e in events:
		state.progression_events.append(e)
	return events


## Store rank (StoreRank): one RANK_UP event per rank climbed; a rank once reached is kept even if reputation falls.
static func _rank(state: GameState, events: Array[Dictionary]) -> void:
	var p: Dictionary = state.progression_state
	var reached := int(p.get("store_rank", 1))
	var now := StoreRank.qualified(int(state.progression_totals["revenue"]), state.reputation)
	if now <= reached:
		return
	p["store_rank"] = now
	for r in range(reached + 1, now + 1):
		events.append({"kind": "RANK_UP", "rank": r})


## The store rank for the screen: {rank, name_ja, top, next: {} at the top else {rank, name_ja, revenue_yen, reputation},
## revenue_yen, reputation, locked: {item: rank}}.
static func rank_view(state: GameState) -> Dictionary:
	var rank := int(state.progression_state.get("store_rank", 1))
	var info := StoreRank.rank_info(rank)
	var next := {}
	if rank < StoreRank.top():
		var n := StoreRank.rank_info(rank + 1)
		next = {"rank": rank + 1, "name_ja": n["name_ja"], "revenue_yen": int(n["revenue_yen"]), "reputation": int(n["reputation"])}
	return {"rank": rank, "name_ja": info["name_ja"], "top": StoreRank.top(), "next": next, "revenue_yen": int(state.progression_totals["revenue"]),
		"reputation": state.reputation, "locked": StoreRank.locked(rank), "gating": state.rank_gating}


# ---------------------------------------------------------------- incremental ledger totals

static func _scan(state: GameState) -> void:
	var t: Dictionary = state.progression_totals
	var rows := state.ledger.transactions
	if int(t["scanned"]) > rows.size():   # a different ledger (e.g. after a load): start over
		t["scanned"] = 0
		t["sales"] = 0
		t["revenue"] = 0
		t["order_qty"] = 0
		t["sales_by_day"] = {}
	while int(t["scanned"]) < rows.size():
		var tx: Dictionary = rows[int(t["scanned"])]
		match tx["event_type"]:
			"SALE":
				t["sales"] += 1
				t["revenue"] += int(tx["revenue_delta_yen"])
				var day := int(tx["day_index"])
				t["sales_by_day"][day] = int(t["sales_by_day"].get(day, 0)) + 1
			"ORDER":
				t["order_qty"] += int(tx["details"].get("qty", 0))
		t["scanned"] += 1


# ---------------------------------------------------------------- tutorial (15 §2)

static func tutorial_step_done(state: GameState, step: int) -> bool:
	var t: Dictionary = state.progression_totals
	match step:
		1:
			return true   # tut_01: the game is running
		2:
			return _count_type(state, "register_basic") >= 1
		3:
			return _sellable_fixtures(state) >= 1
		4:
			return int(t["order_qty"]) >= 10
		5:
			return _accessible_stock(state)
		6:
			return state.business_state != GameState.SETUP or state.time_sec > 0 or BusinessService.day_charged(state, 0)
		7:
			return int(t["sales"]) >= 1
		8:
			for r in state.daily_reports:
				if int(r["day_index"]) == 0:
					return true
	return false


static func _tutorial(state: GameState, events: Array[Dictionary]) -> void:
	var p: Dictionary = state.progression_state
	# A step whose condition already holds is passed at once (15 §3); steps never move back.
	while int(p["tutorial_step_index"]) < TUTORIAL_STEPS and tutorial_step_done(state, int(p["tutorial_step_index"]) + 1):
		p["tutorial_step_index"] = int(p["tutorial_step_index"]) + 1
		events.append({"kind": "TUTORIAL_STEP", "id": "tut_%02d" % int(p["tutorial_step_index"])})


static func _count_type(state: GameState, type_id: String) -> int:
	var n := 0
	for inst in state.grid.instances.values():
		if inst["type_id"] == type_id and inst.get("enabled", true):
			n += 1
	return n


static func _sellable_fixtures(state: GameState) -> int:
	var n := 0
	for inst in state.grid.instances.values():
		if not state.fixtures.get_type(inst["type_id"])["shelf_slots"].is_empty() and inst.get("enabled", true):
			n += 1
	return n


## Some shelf a customer can reach holds at least one unit (tut_05).
static func _accessible_stock(state: GameState) -> bool:
	var reach := PathService.distances(state.grid, state.grid.blocked_cells())
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] != "FIXTURE" or int(seg["physical_qty"]) < 1 or not state.grid.instances.has(loc["fixture_id"]):
			continue
		var inst: Dictionary = state.grid.instances[loc["fixture_id"]]
		var def := state.fixtures.get_type(inst["type_id"])
		if not AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach).is_empty():
			return true
	return false


# ---------------------------------------------------------------- milestones (15 §3)

## `stocked_count` >= 0 lets a caller that already knows it skip the inventory scan.
static func metric_value(state: GameState, metric: String, threshold: int, stocked_count: int = -1) -> int:
	var t: Dictionary = state.progression_totals
	match metric:
		"total_sales_count":
			return int(t["sales"])
		"total_revenue_yen":
			return int(t["revenue"])
		"total_customers_entered":   # every store of the company (#146)
			var total := 0
			for s in Company.stores(state):
				total += int(s.visit_stats["entered"])
				for r in s.daily_reports:
					total += int(r["visitors"])
			return total
		"unique_categories_stocked":
			return stocked_count if stocked_count >= 0 else DemandGenerator.stocked_category_count(state)
		"fixtures_installed_count":
			var n := 0
			for s in Company.stores(state):
				n += s.grid.instances.size()
			return n
		"day_closed_count":
			return state.daily_reports.size()
		"reputation_at_least":
			return state.reputation
		"daily_operating_profit_at_least":   # the best day of any store
			var best := 0
			for s in Company.stores(state):
				for r in s.daily_reports:
					best = maxi(best, int(r["operating_profit_yen"]))
			return best
	return 0


static func _milestones(state: GameState, events: Array[Dictionary]) -> void:
	var done: Array = state.progression_state["completed_milestone_ids"]
	for m in state.milestones:
		if done.has(m["milestone_id"]):
			continue
		if metric_value(state, m["metric"], m["threshold"]) >= int(m["threshold"]):
			done.append(m["milestone_id"])
			events.append({"kind": "MILESTONE", "id": m["milestone_id"], "badge_id": m["reward"]["badge_id"]})
			state.emit_event("MILESTONE_REACHED", {"milestone_id": m["milestone_id"], "name_ja": m["name_ja"]})


## Every milestone with its current value, for the achievements page (SCR-18).
static func milestone_progress(state: GameState, stocked_count: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var done: Array = state.progression_state["completed_milestone_ids"]
	for m in state.milestones:
		var value := metric_value(state, m["metric"], m["threshold"], stocked_count)
		out.append({
			"milestone_id": m["milestone_id"], "name_ja": m["name_ja"], "metric": m["metric"], "threshold": m["threshold"],
			"value": mini(value, int(m["threshold"])), "done": done.has(m["milestone_id"]),
		})
	return out


## Level = how many milestones are done; a progress title, not a strength bonus.
static func level(state: GameState) -> int:
	return state.progression_state["completed_milestone_ids"].size()


# ---------------------------------------------------------------- daily challenge (15 §4)

static func challenge_for_day(day: int) -> String:
	return "" if day < 1 else CHALLENGES[day % 3]


static func challenge_event_id(day: int, challenge_id: String) -> String:
	return "daily:%d:challenge:%s" % [day, challenge_id]


## Today's challenge with how far it has come, for the 本日のミッション list (#32 mockup). Read only; {} on a day
## without a challenge. value is capped at goal; challenge_no_waste is judged when the day closes, so its bar
## only shows that the day has a sale.
static func challenge_progress(state: GameState) -> Dictionary:
	var p: Dictionary = state.progression_state
	var id = p["active_daily_challenge_id"]
	if id == null or int(p["active_daily_challenge_day"]) != state.day:
		return {}
	var done: bool = p["completed_daily_challenge_ids"].has(challenge_event_id(state.day, id))
	var sales := int(state.progression_totals["sales_by_day"].get(state.day, 0))
	var value := 0
	var goal := 1
	match id:
		"challenge_sales_3":
			value = sales
			goal = SALES_GOAL
		"challenge_stock_2":
			value = CATEGORY_GOAL if p.get("challenge_stock_qualified", false) else DemandGenerator.stocked_category_count(state)
			goal = CATEGORY_GOAL
		"challenge_no_waste":
			value = mini(sales, 1)
	if done:
		value = goal
	return {"challenge_id": String(id), "value": mini(value, goal), "goal": goal, "done": done}


static func _challenge(state: GameState, events: Array[Dictionary]) -> void:
	var p: Dictionary = state.progression_state
	var done: Array = p["completed_daily_challenge_ids"]
	# 1. A finished day may settle its "close of day" challenge before the next one is drawn.
	var active_day := int(p["active_daily_challenge_day"])
	if active_day >= 0 and active_day < state.day and p["active_daily_challenge_id"] == "challenge_no_waste":
		for r in state.daily_reports:
			if int(r["day_index"]) == active_day and int(r["wastage_yen"]) == 0 and int(r["purchasing_customers"]) >= 1:
				_finish(state, events, active_day, "challenge_no_waste")
	# 2. The challenge of today is fixed once, by day number (no randomness, no re-draw).
	if state.day >= 1 and active_day != state.day:
		p["active_daily_challenge_day"] = state.day
		p["active_daily_challenge_id"] = challenge_for_day(state.day)
		p["challenge_stock_qualified"] = false
	var id = p["active_daily_challenge_id"]
	if id == null or int(p["active_daily_challenge_day"]) != state.day:
		return
	match id:
		"challenge_sales_3":
			if int(state.progression_totals["sales_by_day"].get(state.day, 0)) >= SALES_GOAL:
				_finish(state, events, state.day, id)
		"challenge_stock_2":
			if state.business_state == GameState.OPEN and DemandGenerator.stocked_category_count(state) >= CATEGORY_GOAL:
				p["challenge_stock_qualified"] = true
			if p["challenge_stock_qualified"]:
				_finish(state, events, state.day, id)


static func _finish(state: GameState, events: Array[Dictionary], day: int, challenge_id: String) -> void:
	var event_id := challenge_event_id(day, challenge_id)
	var done: Array = state.progression_state["completed_daily_challenge_ids"]
	if done.has(event_id):
		return
	done.append(event_id)
	events.append({"kind": "CHALLENGE", "id": event_id, "challenge_id": challenge_id, "day": day})
