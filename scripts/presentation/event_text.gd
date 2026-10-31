class_name EventText
extends RefCounted
## Texts of the daily event panel (SCR-11). Pure: takes the snapshot's "gameplay_event" view.

const CATEGORY_JA := {
	"rice_ball": "おにぎり", "oden": "おでん", "instant_noodle": "カップ麺", "bread": "パン",
	"drink": "飲料", "snack": "おかし", "dessert": "デザート", "ice_cream": "アイス",
	"bento": "弁当", "daily_fresh": "野菜・日配", "coffee": "コーヒー",
	"capsule_toy": "カプセルトイ",
	"daily_goods": "日用品", "hygiene": "衛生用品", "character_goods": "限定グッズ",
	"soft_serve": "ソフトクリーム", "frappe": "フラッペ",
	"bakery": "焼きたてパン", "pizza": "ピザ",
	"crane_prize": "UFOキャッチャー",
}
const STATUS_JA := {"scheduled": "予定", "active": "開催中", "ended": "終了", "missed": "見送り"}


static func clock(sec: int) -> String:
	var t := sec % 86400
	return "%02d:%02d" % [t / 3600, (t % 3600) / 60]


static func effect_text(view: Dictionary) -> String:
	var parts: Array[String] = []
	if absf(float(view["traffic"]) - 1.0) > 0.0001:
		parts.append("来店 ×%.2f" % float(view["traffic"]))
	for cat in view["categories"]:
		parts.append("%s ×%.2f" % [CATEGORY_JA.get(cat, cat), float(view["categories"][cat])])
	return "・".join(parts)


## #31 効果の内訳: one chip per effect against a day without the event, e.g. {text: "来店 −25%", good: false}.
## `view` is a gameplay_event view or a catalog entry (both carry traffic and categories).
static func effect_chips(view: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var t := float(view.get("traffic", 1.0))
	if absf(t - 1.0) > 0.0001:
		out.append(_chip("来店", t))
	var cats: Dictionary = view.get("categories", {})
	for cat in cats:
		out.append(_chip(CATEGORY_JA.get(cat, cat), float(cats[cat])))
	return out


static func _chip(what: String, multiplier: float) -> Dictionary:
	var pct := int(round((multiplier - 1.0) * 100.0))
	return {"text": "%s %s%d%%" % [what, "+" if pct >= 0 else "−", absi(pct)], "good": pct >= 0}


## Hover text of an event in the 本日のイベント一覧: description, hours, effects and why it cannot be drawn yet.
static func catalog_tooltip(e: Dictionary) -> String:
	var fx := "・".join(effect_chips(e).map(func(c): return c["text"]))
	var lines: Array[String] = [String(e["description_ja"]), "時間 %02d:00〜%02d:00" % [int(e["start_hour"]), int(e["end_hour"])], "効果 " + (fx if fx != "" else "なし")]
	if String(e.get("lock", "")) != "":
		lines.append("条件：" + String(e["lock"]))
	return "\n".join(lines)


## Timeline rows for the 本日のイベント card: [{time, text}], at most three. A day without an event gives one row with no
## time. `stocked` as in lines().
static func timeline(view: Dictionary, time_sec: int, stocked: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if view.get("status", "no_data") in ["scheduled", "active", "ended", "missed"]:
		out.append({"time": clock(int(view["start_sec"])), "text": "%s（%s）" % [view["name_ja"], STATUS_JA[view["status"]]]})
		out.append({"time": "", "text": view["description_ja"]})
		out.append({"time": clock(int(view["end_sec"])), "text": "終了 ・ 効果 " + (effect_text(view) if effect_text(view) != "" else "なし")})
		return out
	for line in lines(view, time_sec, stocked).slice(0, 1):
		out.append({"time": "", "text": line})
	return out


## Lines for the panel; `stocked` = category ids that have stock on a shelf now.
static func lines(view: Dictionary, time_sec: int, stocked: Array) -> Array[String]:
	var out: Array[String] = []
	match view["status"]:
		"no_data":
			out.append("日替わりイベントのデータがありません")
		"undrawn":
			out.append("DAY 0 はイベントなし。2日目以降、営業中に1日1回の抽選があります" if int(view.get("day", 0)) < 1 else "営業中に今日のイベントが抽選されます")
		"none":
			out.append("今日の特別なイベントはありません")
		_:
			out.append("%s: %s" % [STATUS_JA[view["status"]], view["name_ja"]])
			out.append(view["description_ja"])
			out.append("時間 %s〜%s" % [clock(view["start_sec"]), clock(view["end_sec"])])
			out.append("効果: " + effect_text(view))
			if view["status"] == "scheduled":
				out.append("開始まで %s" % clock(maxi(int(view["start_sec"]) - time_sec, 0)))
			elif view["status"] == "active":
				out.append("終了まで %s" % clock(maxi(int(view["end_sec"]) - time_sec, 0)))
			elif view["status"] == "missed":
				out.append("営業開始が終了時刻より後だったため、今日は効果がありません")
			if view["status"] in ["scheduled", "active"]:
				var wanted: Array = view["categories"].keys()
				if not wanted.is_empty() and not wanted.any(func(c): return stocked.has(c)):
					out.append("対象の商品が棚にありません。仕入れて陳列すると効果が出ます")
				if view["tone"] == "challenge":
					out.append("品揃えと価格を見直して乗り切りましょう")
	return out
