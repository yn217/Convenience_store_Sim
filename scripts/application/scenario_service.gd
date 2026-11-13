class_name ScenarioService
extends RefCounted
## A scenario in play (ScenarioRules, user's decision 2026-11-14). GameState.scenario holds it — {} in free play, else
## {scenario_id, status ("active" / "cleared" / "failed"), judged_day, result_day} — shared by every store of the company
## and saved in runtime_state. It is judged once per closed day (from the daily reports, no random draws) and the result
## is announced once (SCENARIO_CLEARED / SCENARIO_FAILED); the game goes on as free play either way (spec 15 §9).

const STATUSES := ["active", "cleared", "failed"]


## Sets up a new game for the scenario: its starting cash and reputation and its fixed site. Only before the store
## first opens. Returns "" or an error key.
static func start(state: GameState, scenario_id: String) -> String:
	var sc := ScenarioRules.find(scenario_id)
	if sc.is_empty():
		return "unknown_scenario"
	if state.location_locked():
		return "scenario_needs_new_game"
	var st: Dictionary = sc["start"]
	if st.has("cash_yen"):
		state.ledger.cash_yen = int(st["cash_yen"])
	if st.has("reputation"):
		state.reputation = int(st["reputation"])
	if st.has("map_id"):
		var site := WorldMap.site(String(st["map_id"]), String(st["plot_id"]))
		if site.is_empty():
			return "site_unavailable"
		state.map_id = String(st["map_id"])
		state.plot_id = String(st["plot_id"])
		state.location_id = site["location_id"]
		state.facilities = (site["facilities"] as Array).duplicate()
	if needs_rivals(sc):
		state.rivals_enabled = true
	state.scenario.clear()
	state.scenario.merge({"scenario_id": scenario_id, "status": "active", "judged_day": state.day, "result_day": -1}, true)
	return ""


static func definition(state: GameState) -> Dictionary:
	return ScenarioRules.find(String(state.scenario.get("scenario_id", ""))) if not state.scenario.is_empty() else {}


static func active(state: GameState) -> bool:
	return String(state.scenario.get("status", "")) == "active" and not definition(state).is_empty()


## The scenario fixes the store's site: SET_SITE / SET_LOCATION / SET_FACILITIES are refused.
static func site_fixed(state: GameState) -> bool:
	return (definition(state).get("start", {}) as Dictionary).has("plot_id")


static func needs_rivals(sc: Dictionary) -> bool:
	return (sc.get("goals", []) as Array).any(func(g): return g["metric"] == "rival_closed")


## The measured value of every metric. `live`: today's sales count toward the revenue metrics (for the screen); the
## verdict uses closed days only.
static func values(state: GameState, live := false) -> Dictionary:
	var stores := Company.stores(state)
	var home: GameState = Company.find(state, "")
	if home == null:
		home = state
	var best := 0
	for r in home.daily_reports:
		best = maxi(best, int(r["revenue_yen"]))
	var total := 0
	for s in stores:
		for r in s.daily_reports:
			total += int(r["revenue_yen"])
	if live:
		var today := int(home.today_summary()["revenue_yen"])
		best = maxi(best, today)
		for s in stores:
			total += int(s.today_summary()["revenue_yen"])
	var closed := 0
	for r in state.rivals:
		if r.has("closed_day"):
			closed += 1
	return {"best_day_revenue": best, "total_revenue": total, "reputation": home.reputation, "rival_closed": closed,
		"store_rank": int(state.progression_state.get("store_rank", 1))}


## Called by ProgressionService.evaluate: once a new day has begun, judge the scenario on the days closed so far.
static func judge(state: GameState, events: Array[Dictionary]) -> void:
	if not active(state) or state.day <= int(state.scenario.get("judged_day", 0)):
		return
	var sc := definition(state)
	state.scenario["judged_day"] = state.day
	var verdict := ScenarioRules.verdict(sc, values(state), state.day)
	if verdict == "active":
		return
	state.scenario["status"] = verdict
	state.scenario["result_day"] = state.day - 1   # the day that closed
	events.append({"kind": "SCENARIO_CLEARED" if verdict == "cleared" else "SCENARIO_FAILED", "scenario_id": sc["scenario_id"],
		"days_used": state.day})


## For the screen: {} in free play, else {scenario_id, name_ja, status, days, day, days_left, goals: goal rows, result_day}.
static func view(state: GameState) -> Dictionary:
	var sc := definition(state)
	if sc.is_empty():
		return {}
	var status := String(state.scenario["status"])
	return {"scenario_id": sc["scenario_id"], "name_ja": sc["name_ja"], "summary_ja": sc["summary_ja"], "status": status,
		"days": int(sc["days"]), "day": state.day, "days_left": ScenarioRules.days_left(sc, state.day),
		"goals": ScenarioRules.goal_rows(sc, values(state, status == "active")), "result_day": int(state.scenario.get("result_day", -1))}


## A saved scenario (runtime_state.scenario) back into a state; anything unknown or malformed is dropped (free play).
static func load_saved(raw, out: Dictionary) -> void:
	out.clear()
	if typeof(raw) != TYPE_DICTIONARY or ScenarioRules.find(String(raw.get("scenario_id", ""))).is_empty():
		return
	if not STATUSES.has(String(raw.get("status", ""))) or not JsonCheck.is_int(raw.get("judged_day")) or not JsonCheck.is_int(raw.get("result_day")):
		return
	out.merge({"scenario_id": String(raw["scenario_id"]), "status": String(raw["status"]), "judged_day": int(raw["judged_day"]),
		"result_day": int(raw["result_day"])}, true)
