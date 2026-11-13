class_name RikkaReactions
extends RefCounted
## Rikka's live reactions (data/presentation/rikka_reactions_v1.json): a gameplay cue picks her bust-up reaction and
## one of her lines. Presentation only; it never touches the game state. Lines rotate in order, each cue waits its
## cooldown before it reacts again and two reactions are kept a little apart, so she comments instead of chattering.

const DATA_PATH := "res://data/presentation/rikka_reactions_v1.json"

var show_seconds := 4.0
var global_cooldown := 8.0
var _rows := {}          # cue_id -> {image, lines, cooldown}
var _last_at := {}       # cue_id -> time of its last reaction
var _line_index := {}    # cue_id -> next line
var _last_any := -INF


static func load_default() -> RikkaReactions:
	var r := RikkaReactions.new()
	r.load_text(FileAccess.get_file_as_string(DATA_PATH))
	return r


## A bad file only costs the reactions, never the game: rows without an image or lines are skipped.
func load_text(text: String) -> void:
	_rows.clear()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	show_seconds = maxf(float(data.get("show_seconds", show_seconds)), 0.5)
	global_cooldown = maxf(float(data.get("global_cooldown_sec", global_cooldown)), 0.0)
	for row in data.get("reactions", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var lines: Array = (row.get("lines", []) as Array).filter(func(l): return typeof(l) == TYPE_STRING and not String(l).is_empty())
		var image := String(row.get("image", ""))
		var cue := String(row.get("cue_id", ""))
		if cue.is_empty() or image.is_empty() or lines.is_empty():
			continue
		_rows[cue] = {"image": image, "lines": lines, "cooldown": maxf(float(row.get("cooldown_sec", 60)), 0.0), "symbol": String(row.get("symbol", ""))}


func handles(cue_id: String) -> bool:
	return _rows.has(cue_id)


func cue_ids() -> Array:
	return _rows.keys()


func image_for(cue_id: String) -> String:
	return String(_rows.get(cue_id, {}).get("image", ""))


## {cue_id, image, line, symbol} when she reacts to `cue_id` at `now` (seconds), {} while it or any reaction is cooling down.
## Only a reaction that is returned starts the cooldowns, so a cue that could not be shown is not lost for later.
func pick(cue_id: String, now: float) -> Dictionary:
	if not _rows.has(cue_id):
		return {}
	var row: Dictionary = _rows[cue_id]
	if now - _last_any < global_cooldown:
		return {}
	if _last_at.has(cue_id) and now - float(_last_at[cue_id]) < float(row["cooldown"]):
		return {}
	var lines: Array = row["lines"]
	var i := int(_line_index.get(cue_id, 0)) % lines.size()
	_line_index[cue_id] = i + 1
	_last_at[cue_id] = now
	_last_any = now
	return {"cue_id": cue_id, "image": row["image"], "line": String(lines[i]), "symbol": row["symbol"]}
