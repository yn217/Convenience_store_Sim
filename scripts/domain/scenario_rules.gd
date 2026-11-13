class_name ScenarioRules
extends RefCounted
## Scenarios with a deadline (data/scenarios/scenarios_v1.json, user's decision 2026-11-14). Pure rules: the scenario
## list, the check of the file, and whether a set of measured values meets a scenario's goals. ScenarioService measures
## the values from the game and keeps the scenario's progress; there is no game over (spec 15 §1, §9).

const DATA_PATH := "res://data/scenarios/scenarios_v1.json"
const METRICS := ["best_day_revenue", "total_revenue", "reputation", "rival_closed", "store_rank"]
const METRIC_JA := {
	"best_day_revenue": "1日の売上", "total_revenue": "累計売上", "reputation": "評判", "rival_closed": "撤退させたライバル店",
	"store_rank": "店舗ランク",
}
const MAX_DAYS := 60
const START_KEYS := ["cash_yen", "reputation", "map_id", "plot_id"]

static var _scenarios: Array = []


static func scenarios() -> Array:
	if _scenarios.is_empty():
		var errors: Array[String] = []
		_scenarios = parse(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)), errors)
		if not errors.is_empty():
			push_error("scenarios: %s" % str(errors))
	return _scenarios


static func find(scenario_id: String) -> Dictionary:
	for s in scenarios():
		if String(s["scenario_id"]) == scenario_id:
			return s
	return {}


## The valid scenarios of a file; each problem goes to `errors` and its scenario is left out.
static func parse(data, errors: Array[String] = []) -> Array:
	var out: Array = []
	var rows = data.get("scenarios", null) if typeof(data) == TYPE_DICTIONARY else null
	if typeof(rows) != TYPE_ARRAY:
		errors.append("scenarios: missing")
		return out
	var seen := {}
	for i in rows.size():
		var r = rows[i]
		var before := errors.size()
		if typeof(r) != TYPE_DICTIONARY:
			errors.append("scenarios[%d]: not an object" % i)
			continue
		var id := String(r.get("scenario_id", ""))
		if id == "" or seen.has(id):
			errors.append("scenarios[%d]: scenario_id missing or repeated" % i)
		seen[id] = true
		for k in ["name_ja", "summary_ja", "intro_ja", "clear_ja", "fail_ja"]:
			if not JsonCheck.is_nonempty_string(r.get(k)):
				errors.append("scenarios[%d]: %s missing" % [i, k])
		if not JsonCheck.is_int(r.get("days")) or int(r["days"]) < 1 or int(r["days"]) > MAX_DAYS:
			errors.append("scenarios[%d]: days must be 1..%d" % [i, MAX_DAYS])
		var start = r.get("start", {})
		if typeof(start) != TYPE_DICTIONARY:
			errors.append("scenarios[%d]: start not an object" % i)
			start = {}
		for k in start:
			if not START_KEYS.has(k):
				errors.append("scenarios[%d]: unknown start key %s" % [i, k])
		if start.has("cash_yen") and (not JsonCheck.is_int(start["cash_yen"]) or int(start["cash_yen"]) < 0):
			errors.append("scenarios[%d]: start.cash_yen invalid" % i)
		if start.has("reputation") and (not JsonCheck.is_int(start["reputation"]) or int(start["reputation"]) < 0 or int(start["reputation"]) > 100):
			errors.append("scenarios[%d]: start.reputation invalid" % i)
		if start.has("map_id") != start.has("plot_id"):
			errors.append("scenarios[%d]: start needs both map_id and plot_id" % i)
		var goals = r.get("goals", [])
		if typeof(goals) != TYPE_ARRAY or goals.is_empty():
			errors.append("scenarios[%d]: goals missing" % i)
			goals = []
		for g in goals:
			if typeof(g) != TYPE_DICTIONARY or not METRICS.has(String(g.get("metric", ""))) or not JsonCheck.is_int(g.get("target")) or int(g["target"]) < 1:
				errors.append("scenarios[%d]: goal %s invalid" % [i, str(g)])
		if errors.size() > before:
			continue
		var goals_out: Array = []
		for g in goals:
			goals_out.append({"metric": String(g["metric"]), "target": int(g["target"])})
		out.append({
			"scenario_id": id, "name_ja": String(r["name_ja"]), "summary_ja": String(r["summary_ja"]),
			"difficulty": clampi(int(r.get("difficulty", 1)), 1, 3), "days": int(r["days"]), "start": (start as Dictionary).duplicate(),
			"goals": goals_out, "intro_ja": String(r["intro_ja"]), "clear_ja": String(r["clear_ja"]), "fail_ja": String(r["fail_ja"]),
		})
	return out


## Each goal with its measured value: [{metric, target, value, done}]. `values` maps a metric to its value.
static func goal_rows(scenario: Dictionary, values: Dictionary) -> Array:
	var out: Array = []
	for g in scenario.get("goals", []):
		var v := int(values.get(g["metric"], 0))
		out.append({"metric": g["metric"], "target": int(g["target"]), "value": v, "done": v >= int(g["target"])})
	return out


static func all_met(scenario: Dictionary, values: Dictionary) -> bool:
	return goal_rows(scenario, values).all(func(row): return row["done"])


## The verdict when the game reaches day `day` (the day before it has closed): "cleared" when every goal is met,
## "failed" once the scenario's days are over, else "active". A clear on the last day counts.
static func verdict(scenario: Dictionary, values: Dictionary, day: int) -> String:
	if all_met(scenario, values):
		return "cleared"
	if day >= int(scenario["days"]):
		return "failed"
	return "active"


## The days left counting today (0 once over): day 0 of a 7-day scenario has 7 days left.
static func days_left(scenario: Dictionary, day: int) -> int:
	return maxi(int(scenario["days"]) - day, 0)

