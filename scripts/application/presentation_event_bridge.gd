class_name PresentationEventBridge
extends RefCounted
## Domain EventEnvelope {id, tick, type, payload} -> CueRequest (14 §1, §5; 01 §11). One way only:
## the bridge reads events and never touches money, stock or customers, and nothing waits for a cue
## to finish. A cue fires at most once per event id (a snapshot rebuilt from the same events cannot
## play it twice), and cues with a cooldown skip repeats for the same payload value
## (e.g. the same shelf's low-stock notice within 30 game seconds).

const PRIORITIES := ["critical", "important", "normal", "ambient"]
const SEEN_CAP := 4096
const KEYS := ["schema_version", "cue_id", "source_event_type", "animation_id", "duration_seconds", "priority", "sfx_key", "dedupe_payload_field", "cooldown_game_seconds"]

var _by_event: Dictionary = {}
var _seen: Dictionary = {}
var _seen_order: Array[String] = []
var _last_fired: Dictionary = {}


## Parsed cue definitions, or [] with problems in `errors`.
static func load_cues(data, errors: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(data) != TYPE_ARRAY:
		errors.append("$: not_array")
		return out
	var ids := {}
	var events := {}
	for i in data.size():
		var c = data[i]
		var path := "cues[%d]" % i
		if typeof(c) != TYPE_DICTIONARY:
			errors.append("%s: not_object" % path)
			continue
		var errs := JsonCheck.key_errors(c, KEYS, [], path)
		errors.append_array(errs)
		if not errs.is_empty():
			continue
		var before := errors.size()
		if int(c["schema_version"]) != 1:
			errors.append("%s.schema_version: unsupported" % path)
		if not JsonCheck.is_nonempty_string(c["cue_id"]) or ids.has(c["cue_id"]):
			errors.append("%s.cue_id: invalid_or_duplicate" % path)
		ids[c["cue_id"]] = true
		if not JsonCheck.is_nonempty_string(c["source_event_type"]) or events.has(c["source_event_type"]):
			errors.append("%s.source_event_type: invalid_or_duplicate" % path)
		events[c["source_event_type"]] = true
		if not PRIORITIES.has(c["priority"]):
			errors.append("%s.priority: unknown" % path)
		if typeof(c["duration_seconds"]) not in [TYPE_INT, TYPE_FLOAT] or float(c["duration_seconds"]) < 0.0 or float(c["duration_seconds"]) > 5.0:
			errors.append("%s.duration_seconds: out_of_range" % path)
		if not JsonCheck.is_int(c["cooldown_game_seconds"]) or int(c["cooldown_game_seconds"]) < 0 or int(c["cooldown_game_seconds"]) > 3600:
			errors.append("%s.cooldown_game_seconds: out_of_range" % path)
		if c["sfx_key"] != null and not JsonCheck.is_nonempty_string(c["sfx_key"]):
			errors.append("%s.sfx_key: invalid" % path)
		if not JsonCheck.is_nonempty_string(c["dedupe_payload_field"]):
			errors.append("%s.dedupe_payload_field: empty" % path)
		if errors.size() == before:
			out.append(c)
	return out


func setup(cues: Array[Dictionary]) -> void:
	_by_event.clear()
	for c in cues:
		_by_event[c["source_event_type"]] = c
	reset()


func reset() -> void:
	_seen.clear()
	_seen_order.clear()
	_last_fired.clear()


func cue_count() -> int:
	return _by_event.size()


## Cue requests for events not seen before; `now_sec` is the game clock for the cooldowns.
func map(events: Array, now_sec: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		var id: String = e["id"]
		if _seen.has(id):
			continue
		_remember(id)
		var cue: Dictionary = _by_event.get(e["type"], {})
		if cue.is_empty():
			continue
		var payload: Dictionary = e["payload"]
		var cooldown := int(cue["cooldown_game_seconds"])
		if cooldown > 0:
			var key := "%s|%s" % [cue["cue_id"], str(payload.get(cue["dedupe_payload_field"], ""))]
			if _last_fired.has(key) and now_sec - int(_last_fired[key]) < cooldown:
				continue
			_last_fired[key] = now_sec
		out.append({
			"cue_id": cue["cue_id"], "source_event_id": id, "tick": int(e["tick"]), "priority": cue["priority"],
			"animation_id": cue["animation_id"], "sfx_key": cue["sfx_key"], "duration_seconds": float(cue["duration_seconds"]),
			"payload": payload,
		})
	return out


func _remember(id: String) -> void:
	_seen[id] = true
	_seen_order.append(id)
	if _seen_order.size() > SEEN_CAP:
		_seen.erase(_seen_order.pop_front())
