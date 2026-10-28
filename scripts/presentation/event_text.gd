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
