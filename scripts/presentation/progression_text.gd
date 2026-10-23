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
