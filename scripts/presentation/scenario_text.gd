class_name ScenarioText
extends RefCounted
## Scenario words for the screen (ScenarioRules / ScenarioService views) and the player's clear records, kept on this
## computer in user://scenario_records.json ({scenario_id: {best_days}}) so the title screen can show クリア済み. The
## records are a convenience: a missing or broken file only means no record is shown.

const RECORDS_PATH := "user://scenario_records.json"

static var records_path := RECORDS_PATH   # tests point this at a scratch file


static func format_value(metric: String, value: int) -> String:
	match metric:
		"best_day_revenue", "total_revenue":
			return GameHud.format_yen(value)
		"store_rank":
			return StoreRank.stars(value)
		"rival_closed":
			return "%d店" % value
	return str(value)


## "✓ 1日の売上 ¥312,000 / ¥300,000" (the mark only when met).
static func goal_text(row: Dictionary) -> String:
	var metric := String(row["metric"])
	return "%s%s %s / %s" % ["✓ " if row["done"] else "・", String(ScenarioRules.METRIC_JA.get(metric, metric)),
		format_value(metric, int(row["value"])), format_value(metric, int(row["target"]))]


## A goal as the title screen states it, before any play: "1日の売上 ¥300,000".
static func target_text(goal: Dictionary) -> String:
	var metric := String(goal["metric"])
	return "%s %s" % [String(ScenarioRules.METRIC_JA.get(metric, metric)), format_value(metric, int(goal["target"]))]


static func difficulty_text(level: int) -> String:
	return "難しさ " + "★".repeat(level) + "☆".repeat(3 - level)


## The lines of the goal panel: the scenario, the days left or the result, each goal with its value.
static func panel_text(view: Dictionary) -> String:
	if view.is_empty():
		return ""
	var head := "シナリオ「%s」" % String(view["name_ja"])
	match String(view["status"]):
		"cleared":
			head += "　クリア！（%d日目）" % (int(view["result_day"]) + 1)
		"failed":
			head += "　期限終了（フリープレイ中）"
		_:
			head += "　残り%d日（%d日目 / %d日）" % [int(view["days_left"]), mini(int(view["day"]) + 1, int(view["days"])), int(view["days"])]
	var lines: Array[String] = [head]
	for row in view["goals"]:
		lines.append(goal_text(row))
	return "\n".join(lines)


static func read_records() -> Dictionary:
	if not FileAccess.file_exists(records_path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(records_path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## Records a clear in `days`; keeps the fewest days. Returns true when it is a new best.
static func record_clear(scenario_id: String, days: int) -> bool:
	var records := read_records()
	var old = records.get(scenario_id, {})
	var best := int(old.get("best_days", 0)) if typeof(old) == TYPE_DICTIONARY else 0
	if best > 0 and best <= days:
		return false
	records[scenario_id] = {"best_days": days}
	var f := FileAccess.open(records_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(records, "  "))
	return true


## "クリア済み（最短5日）" or "".
static func record_text(scenario_id: String, records: Dictionary) -> String:
	var r = records.get(scenario_id, {})
	if typeof(r) != TYPE_DICTIONARY or int(r.get("best_days", 0)) <= 0:
		return ""
	return "クリア済み（最短%d日）" % int(r["best_days"])
