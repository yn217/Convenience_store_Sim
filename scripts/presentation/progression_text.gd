class_name ProgressionText
extends RefCounted
## Local fixed texts for the tutorial, the daily challenge and the manager assistant (15 §2, §4, §5).
## No generated or online text: every line is in this file.

const TUTORIAL: Array[String] = [
	"店舗を見渡してみましょう（ズームとパンは自由です）",
	"レジを一台置きましょう",
	"飲料冷蔵庫か棚を置きましょう",
	"商品を10個以上発注しましょう",
	"買った商品を棚に補充しましょう",
	"準備ができたら営業を開始しましょう",
	"最初の会計を見届けましょう",
	"最初の1日の売上を振り返りましょう（0:00 に日次レポートができます）",
]
const CHALLENGE := {
	"challenge_sales_3": "今日のチャレンジ: 3件以上の会計を達成しよう",
	"challenge_stock_2": "今日のチャレンジ: 営業中に2カテゴリ以上を棚に揃えよう",
	"challenge_no_waste": "今日のチャレンジ: 廃棄ゼロで1日を締めよう（会計1件以上）",
}


static func step_text(step_index: int) -> String:
	if step_index >= TUTORIAL.size():
		return "チュートリアルはすべて完了しました"
	return "手順 %d/%d: %s" % [step_index + 1, TUTORIAL.size(), TUTORIAL[step_index]]


static func challenge_text(challenge_id) -> String:
	if challenge_id == null:
		return "チャレンジは2日目から始まります"
	return CHALLENGE.get(challenge_id, "")


## One-line notice for an achievement event from ProgressionService.
static func notice(event: Dictionary, milestones: Array) -> String:
	match event["kind"]:
		"TUTORIAL_STEP":
			var n := int(String(event["id"]).right(2))
			return "手順 %d 完了: %s" % [n, TUTORIAL[n - 1]]
		"MILESTONE":
			for m in milestones:
				if m["milestone_id"] == event["id"]:
					return "称号を獲得: %s（%d %s）" % [m["name_ja"], int(m["threshold"]), metric_unit(m["metric"])]
			return "称号を獲得しました"
		"CHALLENGE":
			return "チャレンジ達成！ %s" % CHALLENGE.get(event["challenge_id"], "")
	return ""


## What the assistant says when she celebrates an achievement (#32 達成演出): titles and daily challenges only;
## tutorial steps stay in the notices. "" means no celebration.
static func celebration(event: Dictionary, milestones: Array) -> String:
	match event["kind"]:
		"MILESTONE":
			for m in milestones:
				if m["milestone_id"] == event["id"]:
					return "やりましたね、店長！\n称号「%s」を獲得しました。" % m["name_ja"]
			return "やりましたね、店長！\n新しい称号を獲得しました。"
		"CHALLENGE":
			return "今日のチャレンジ達成です！\n%s" % String(CHALLENGE.get(event["challenge_id"], "")).trim_prefix("今日のチャレンジ: ")
	return ""


## What the assistant says over the day-end card (#19/#32 mockup 営業結果): praise or comfort for the result, the
## change from the day before, and one tip from the day's numbers. `reports` are the closed days, newest last.
static func day_end_remark(reports: Array) -> String:
	if reports.is_empty():
		return ""
	var r: Dictionary = reports.back()
	if int(r["purchasing_customers"]) == 0:
		return "今日もお疲れさまでした。\n今日はお買い上げがありませんでした。棚に商品を並べて、営業を始めてみましょう！"
	var lines: Array[String] = []
	if int(r["operating_profit_yen"]) >= 0:
		lines.append("今日もお疲れさまでした！黒字で締められましたね。")
	else:
		lines.append("今日もお疲れさまでした。赤字でしたが、まだまだこれからです！")
	if reports.size() >= 2:
		var d := int(r["revenue_yen"]) - int((reports[reports.size() - 2] as Dictionary)["revenue_yen"])
		if d > 0:
			lines.append("売上は前日より %s 増えました！" % GameHud.format_yen(d))
		elif d < 0:
			lines.append("売上は前日より %s 減りました。" % GameHud.format_yen(-d))
	lines.append(_day_end_tip(r))
	return "\n".join(lines)


## Her face over the day-end card: worried on a loss or a day without a sale, happy otherwise.
static func day_end_mood(r: Dictionary) -> String:
	if int(r.get("purchasing_customers", 0)) == 0 or int(r.get("operating_profit_yen", 0)) < 0:
		return "worried"
	return "happy"


## The one tip of the day-end remark: the most pressing thing in the day's numbers, else a cheer.
static func _day_end_tip(r: Dictionary) -> String:
	if int(r.get("balked_customers", 0)) > 0:
		return "混雑で引き返したお客様が %d 人いました。レジや店員を増やすと良さそうです。" % int(r["balked_customers"])
	if int(r["lost_customers"]) > 0:
		return "買えずに帰ったお客様が %d 人いました。品揃えと在庫を確かめましょう。" % int(r["lost_customers"])
	if int(r["wastage_yen"]) > 0:
		return "廃棄が %s ありました。仕入れの量を見直してみましょう。" % GameHud.format_yen(int(r["wastage_yen"]))
	if r.has("satisfaction") and int(r["satisfaction"]) < 60:
		return "お客様の満足度が %d でした。品切れやレジ待ちを減らしましょう。" % int(r["satisfaction"])
	return "この調子で、もっと素敵なお店にしていきましょうね！"


## The rows of the 本日のミッション list (#32 mockup, without its cash/EXP rewards: the badge is the only reward):
## today's challenge, then the unfinished titles closest to done (by share, ties in data order), `titles` of them.
## Each row is {kind: "challenge"|"title", caption, goal, value, goal_value, done}.
static func mission_rows(challenge: Dictionary, progress: Array, titles: int = 3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not challenge.is_empty():
		var what := String(CHALLENGE.get(challenge["challenge_id"], "")).trim_prefix("今日のチャレンジ: ")
		if challenge["challenge_id"] == "challenge_no_waste":
			what += "（閉店時に判定）"
		out.append({"kind": "challenge", "caption": "今日のチャレンジ", "goal": what,
				"value": int(challenge["value"]), "goal_value": int(challenge["goal"]), "done": bool(challenge["done"])})
	var open: Array = progress.filter(func(e): return not e["done"])
	var order := range(open.size())
	order.sort_custom(func(a, b):
		var ra := float(open[a]["value"]) / maxf(float(open[a]["threshold"]), 1.0)
		var rb := float(open[b]["value"]) / maxf(float(open[b]["threshold"]), 1.0)
		return ra > rb if not is_equal_approx(ra, rb) else a < b)
	for i in order.slice(0, titles):
		var e: Dictionary = open[i]
		out.append({"kind": "title", "caption": "称号「%s」" % e["name_ja"], "goal": goal_text(e["metric"], int(e["threshold"])),
				"value": int(e["value"]), "goal_value": int(e["threshold"]), "done": false})
	return out


## The goal sentence for the 本日の目標 card: what the next milestone asks for, e.g. "累計 10 件の会計を達成しよう".
static func goal_text(metric: String, threshold: int) -> String:
	match metric:
		"total_sales_count":
			return "累計 %d 件の会計を達成しよう" % threshold
		"total_revenue_yen":
			return "累計売上 %s にしよう" % GameHud.format_yen(threshold)
		"total_customers_entered":
			return "累計 %d 人のお客様を迎えよう" % threshold
		"unique_categories_stocked":
			return "%d カテゴリの品揃えにしよう" % threshold
		"fixtures_installed_count":
			return "什器を %d 台に増やそう" % threshold
		"day_closed_count":
			return "%d 日間の営業を続けよう" % threshold
		"reputation_at_least":
			return "評判を %d 点まで上げよう" % threshold
		"daily_operating_profit_at_least":
			return "1日の営業利益 %s を目指そう" % GameHud.format_yen(threshold)
	return ""


static func metric_unit(metric: String) -> String:
	match metric:
		"total_sales_count":
			return "件の会計"
		"total_customers_entered":
			return "人の来店"
		"unique_categories_stocked":
			return "カテゴリの品揃え"
		"fixtures_installed_count":
			return "台の什器"
		"day_closed_count":
			return "日の営業"
		"total_revenue_yen":
			return "円の売上"
		"reputation_at_least":
			return "点の評判"
		"daily_operating_profit_at_least":
			return "円以上の黒字の日"
	return ""

const ASSISTANT := {
	"story_start": "小さなコンビニですが、どんなお店にするかはあなた次第です。",
	"story_register": "会計の準備ができました。次は売場を作りましょう。",
	"story_first_restock": "棚がにぎやかになってきました。開店してお客さんの反応を見ましょう。",
	"story_first_sale": "はじめての商品が売れました！ 在庫と現金を確認できます。",
	"story_first_profit": "今月ではなく、今日は利益が出ています。仕入れの支払いと利益の違いにも注目しましょう。",
	"story_sold_out": "この棚は売切れです。閉店して補充するか、次の営業の品揃えを工夫しましょう。",
	"story_queue_giveup": "行列で帰ったお客さんがいます。レジ周辺の動線を見直すと改善するかもしれません。",
	"story_staff_short": "レジが混んで、入口で引き返したお客さんがいます。「店員」タブで採用を検討しましょう。",
	"story_event": "今日は飲料が人気です。棚を補充していたら売れ方の違いが見えるかもしれません。",
}


static func assistant_text(cue_id: String) -> String:
	return ASSISTANT.get(cue_id, "")


## One line per milestone for the achievements page: mark, name, and how far along it is.
static func progress_line(entry: Dictionary) -> String:
	return "%s %s（%d/%d %s）" % ["✓" if entry["done"] else "・", entry["name_ja"], int(entry["value"]), int(entry["threshold"]), metric_unit(entry["metric"])]
