class_name CueText
extends RefCounted
## Fixed Japanese notice texts of the cues (14 §2). Every cue that matters has a text, so muting
## the sound or turning off the motion never hides information.


const ACHIEVEMENT_PREFIX := "称号を獲得"


## Achievement toasts get the warm-bordered pill (ToastAchievement look in CueLayer).
static func is_achievement(toast: String) -> bool:
	return toast.begins_with(ACHIEVEMENT_PREFIX)


## Notification level of a cue (NotificationPolicy). The table covers the cues that have a notice; any other
## critical cue is an error, the rest are info.
const LEVEL_OF := {
	"milestone_celebrate": "achievement",
	"expiry_notice": "warning", "low_stock_notice": "warning", "long_queue": "warning",
	"daily_event_start": "info", "daily_event_end": "info", "daily_recap": "info",
	"rival_opened": "warning", "rival_sale": "info", "condition_started": "info", "rival_renovation": "info", "rival_closed": "achievement",   # #129
	"capsule_rare": "info", "capsule_empty": "warning",   # #139
	"crane_won": "info", "crane_empty": "warning",   # #132
	"bake_done": "info",   # #130
	"lottery_top": "info", "lottery_sold_out": "achievement",   # #138
}


static func level_of(cue_id: String, cue_priority: String) -> String:
	if LEVEL_OF.has(cue_id):
		return LEVEL_OF[cue_id]
	return "error" if cue_priority == "critical" else "info"


## `count` > 1 means the notice merged several cues (payload "count"); `qty` is the merged total.
static func toast_text(cue_id: String, payload: Dictionary, fixture_name: String = "") -> String:
	var count := int(payload.get("count", 1))
	match cue_id:
		"low_stock_notice":
			if count > 1:
				return "残りわずか: %d 件の棚" % count
			return "残りわずか: %s" % (fixture_name if fixture_name != "" else "棚")
		"expiry_notice":
			var qty := int(payload.get("qty", 0))
			if count > 1:
				return "期限切れの商品を廃棄しました（計%d個）" % qty
			return "期限切れの商品を廃棄しました（%d個）" % qty
		"long_queue":
			return "レジの待ち時間が増えています"
		"daily_recap":
			return "営業日が終わりました。日次レポートを確認しましょう"
		"milestone_celebrate":
			return "%s: %s" % [ACHIEVEMENT_PREFIX, String(payload.get("name_ja", ""))]
		"daily_event_start":
			return "今日のイベント: %s" % String(payload.get("name_ja", ""))
		"daily_event_end":
			return "イベントが終わりました: %s" % String(payload.get("name_ja", ""))
		"rival_opened":
			return "地域ニュース: 近くにライバル店「%s」が開店しました" % String(payload.get("name", ""))
		"rival_sale":
			return "地域ニュース: ライバル店「%s」が特売を始めました" % String(payload.get("name", ""))
		"rival_renovation":
			return "地域ニュース: ライバル店「%s」が改装のため%d日休業します" % [String(payload.get("name", "")), int(payload.get("days", 0))]
		"rival_closed":
			return "地域ニュース: ライバル店「%s」が閉店しました" % String(payload.get("name", ""))
		"bake_done":
			return "焼きたて「%s」が焼き上がりました（%d個）" % [String(payload.get("name", "")), int(payload.get("qty", 0))]
		"crane_won":
			return "UFOキャッチャーで「%s」が取れました（%d回目）" % [String(payload.get("prize", "")), int(payload.get("plays", 1))]
		"crane_empty":
			return "UFOキャッチャーの景品がなくなりました。補充しましょう"
		"capsule_empty":
			return "カプセルトイ「%s」が空になりました。補充しましょう" % String(payload.get("name", ""))
		"capsule_rare":
			return "カプセルトイ: レアの「%s」が出ました（%s）" % [String(payload.get("prize", "")), String(payload.get("name", ""))]
		"lottery_top":
			return "店頭くじ: %sの「%s」が出ました" % [String(payload.get("set", "")), String(payload.get("prize", ""))]
		"lottery_sold_out":
			return "店頭くじ: %sが完売しました（最後の1枚に「%s」）" % [String(payload.get("set", "")), String(payload.get("last_one", ""))]
		"condition_started":
			return "地域ニュース: %s（%s）" % [String(payload.get("name_ja", "")), String(payload.get("note", ""))]
	return ""
