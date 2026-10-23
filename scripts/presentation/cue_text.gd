class_name CueText
extends RefCounted
## Fixed Japanese notice texts of the cues (14 §2). Every cue that matters has a text, so muting
## the sound or turning off the motion never hides information.


const ACHIEVEMENT_PREFIX := "称号を獲得"


## Achievement toasts get the warm-bordered pill (ToastAchievement look in CueLayer).
static func is_achievement(toast: String) -> bool:
	return toast.begins_with(ACHIEVEMENT_PREFIX)


static func toast_text(cue_id: String, payload: Dictionary, fixture_name: String = "") -> String:
	match cue_id:
		"low_stock_notice":
			return "残りわずか: %s" % (fixture_name if fixture_name != "" else "棚")
		"expiry_notice":
			return "期限切れの商品を廃棄しました（%d個）" % int(payload.get("qty", 0))
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
	return ""
