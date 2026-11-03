class_name EventCardTheme
extends RefCounted
## The look of the bottom bar's 本日のイベント card per event (data/events visual_theme): the card's colours, its small
## decorations and its picture (assets/ui/art/event_<theme>.png), and the state tag (開催中 / 終了間近 / 開催予定 /
## 終了 / なし). Presentation only.

const ENDING_SEC := 3600          # 終了間近 within the last in-game hour
## top / bottom of the card, its rim line, the tag colour, decoration [glyph or art name, tint]
const THEMES := {
	"festival": {"top": "fff2df", "bottom": "ffc98f", "inner": "ff9a52", "tag": "e8562a", "decor": ["star", "ffb020"]},
	"roadworks": {"top": "fff6d6", "bottom": "f1d77a", "inner": "c9a43a", "tag": "8a6d1e", "decor": ["tools", "a08a5a"]},
	"sun": {"top": "fff8d8", "bottom": "ffd77a", "inner": "ffae3a", "tag": "f08a10", "decor": ["sun", "ffb020"]},
	"cold": {"top": "f0f8ff", "bottom": "bfdcff", "inner": "7fb2f0", "tag": "3f7fd0", "decor": ["snow", "ffffff"]},
	"dessert": {"top": "fff3f8", "bottom": "ffd2e3", "inner": "ff9fc1", "tag": "e04880", "decor": ["sakura", "ffffff"]},
	"snack": {"top": "fff5e0", "bottom": "ffd99a", "inner": "f6a64a", "tag": "e07a18", "decor": ["star", "ffffff"]},
	"social": {"top": "f1fbef", "bottom": "c5ecc0", "inner": "7fcf78", "tag": "3a9a48", "decor": ["heart", "ff7fa0"]},
	"quiet": {"top": "f1f1f4", "bottom": "cfd2dc", "inner": "9aa0b4", "tag": "6a7088", "decor": ["dot", "ffffff"]},
	"lunch": {"top": "fbfbe6", "bottom": "e2ecaa", "inner": "b6c85a", "tag": "6f8a1e", "decor": ["star", "ffffff"]},
	"drink": {"top": "eefcff", "bottom": "b6ecf6", "inner": "62c6dc", "tag": "1f97b8", "decor": ["dot", "ffffff"]},
	"bread": {"top": "fff8ea", "bottom": "f3d6a6", "inner": "d6a35e", "tag": "a8692a", "decor": ["star", "fff4d8"]},
	"evening": {"top": "f1ecff", "bottom": "c6b6f0", "inner": "8f78d8", "tag": "5a46a8", "decor": ["moon", "ffe58a"]},
	"none": {"top": "fbf7f0", "bottom": "e8ddcc", "inner": "c9b9a2", "tag": "9a8a78", "decor": ["", ""]},
}


## The theme of the event the card shows; "none" when no event is drawn for the day.
static func theme_id(view: Dictionary) -> String:
	if String(view.get("status", "")) in ["scheduled", "active", "ended", "missed"]:
		var t := String(view.get("visual_theme", ""))
		return t if THEMES.has(t) else "dessert"
	return "none"


static func theme(view: Dictionary) -> Dictionary:
	return THEMES[theme_id(view)]


## The state tag: {"text", "state"}; state is active / ending / scheduled / ended / none.
static func tag(view: Dictionary, now_sec: int) -> Dictionary:
	match String(view.get("status", "")):
		"active":
			if int(view.get("end_sec", 0)) - now_sec <= ENDING_SEC:
				return {"text": "終了間近！", "state": "ending"}
			return {"text": "開催中！", "state": "active"}
		"scheduled":
			return {"text": "開催予定", "state": "scheduled"}
		"ended", "missed":
			return {"text": "終了", "state": "ended"}
	return {"text": "なし", "state": "none"}


## The tag's fill (top, bottom) for its state: the theme colour while it runs, red when ending, muted otherwise.
static func tag_colors(view: Dictionary, now_sec: int) -> Array:
	var state := String(tag(view, now_sec)["state"])
	if state == "ending":
		return [Color("ff5a3c"), Color("c8221a")]
	if state in ["ended", "none"]:
		return [Color("b7aa9a"), Color("8a7d6e")]
	var c := Color(String(theme(view)["tag"]))
	return [c.lightened(0.18), c.darkened(0.12)]


## The event's own picture (assets/ui/art/event_<theme>.png), or null (the card then shows a product or the store).
static func picture(view: Dictionary) -> Texture2D:
	var id := theme_id(view)
	if id != "none":
		var own := MockStyle.art("event_" + id)
		if own != null:
			return own
	return null
