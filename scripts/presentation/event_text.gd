class_name EventText
extends RefCounted
## Texts of the daily event panel (SCR-11). Pure: takes the snapshot's "gameplay_event" view.

const CATEGORY_JA := {
	"rice_ball": "おにぎり", "oden": "おでん", "instant_noodle": "カップ麺", "bread": "パン",
	"drink": "飲料", "snack": "おかし", "dessert": "デザート", "ice_cream": "アイス",
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
