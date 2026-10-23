class_name GameplayEventDirector
extends RefCounted
## Daily gameplay events (13): pure rules, no scene / audio / state classes. One draw per day from DAY 1
## with the independent `events` LCG32 stream; the effect is only a traffic multiplier and category
## weight multipliers while the event window is active. It never moves cash, stock or prices.

const NONE_WEIGHT := 30
const SECONDS_PER_HOUR := 3600
const SECONDS_PER_DAY := 86400
const CATEGORIES := ["rice_ball", "oden", "instant_noodle", "bread", "drink", "snack", "dessert", "ice_cream"]
const KEYS := ["schema_version", "event_id", "name_ja", "description_ja", "weight", "min_day_index", "min_reputation",
		"window_start_hour", "window_end_hour", "effects", "visual_theme", "tone"]
const TRAFFIC_RANGE := Vector2(0.70, 1.40)
const CATEGORY_RANGE := Vector2(1.0, 1.80)


## Parsed event list (gameplay_event.schema.json + semantic checks), problems in `errors`.
static func load_events(data, errors: Array[String] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(data) != TYPE_ARRAY:
		errors.append("$: not_array")
		return out
	var ids := {}
	for i in data.size():
		var e = data[i]
		var path := "events[%d]" % i
		if typeof(e) != TYPE_DICTIONARY:
			errors.append("%s: not_object" % path)
			continue
		var errs := JsonCheck.key_errors(e, KEYS, [], path)
		errors.append_array(errs)
		if not errs.is_empty():
			continue
		var before := errors.size()
		if int(e["schema_version"]) != 1:
			errors.append("%s.schema_version: unsupported" % path)
		if typeof(e["event_id"]) != TYPE_STRING or not String(e["event_id"]).begins_with("evt_") or ids.has(e["event_id"]):
			errors.append("%s.event_id: invalid_or_duplicate" % path)
		ids[e["event_id"]] = true
		if not JsonCheck.is_nonempty_string(e["name_ja"]) or not JsonCheck.is_nonempty_string(e["description_ja"]):
			errors.append("%s: empty text" % path)
		if not JsonCheck.is_int(e["weight"]) or int(e["weight"]) < 1 or int(e["weight"]) > 100:
			errors.append("%s.weight: out_of_range" % path)
		if not JsonCheck.is_int(e["min_day_index"]) or int(e["min_day_index"]) < 1:
			errors.append("%s.min_day_index: invalid" % path)
		if not JsonCheck.is_int(e["min_reputation"]) or int(e["min_reputation"]) < 0 or int(e["min_reputation"]) > 100:
			errors.append("%s.min_reputation: out_of_range" % path)
		if not JsonCheck.is_int(e["window_start_hour"]) or not JsonCheck.is_int(e["window_end_hour"]) \
				or int(e["window_start_hour"]) < 0 or int(e["window_end_hour"]) > 24 or int(e["window_start_hour"]) >= int(e["window_end_hour"]):
			errors.append("%s: window_start_hour must be below window_end_hour (0..24)" % path)
		if typeof(e["effects"]) != TYPE_DICTIONARY:
			errors.append("%s.effects: not_object" % path)
		else:
			errors.append_array(_effect_errors(e["effects"], path + ".effects"))
		if not ["opportunity", "challenge"].has(e["tone"]):
			errors.append("%s.tone: unknown" % path)
		if typeof(e["visual_theme"]) != TYPE_STRING or String(e["visual_theme"]).is_empty():
			errors.append("%s.visual_theme: invalid" % path)
		if errors.size() == before:
			var copy: Dictionary = e.duplicate(true)
			for k in ["weight", "min_day_index", "min_reputation", "window_start_hour", "window_end_hour"]:
				copy[k] = int(copy[k])
			out.append(copy)
	return out


static func _effect_errors(fx: Dictionary, path: String) -> Array[String]:
	var errs := JsonCheck.key_errors(fx, ["traffic_multiplier", "category_weight_multipliers"], [], path)
	if not errs.is_empty():
		return errs
	if not JsonCheck.is_number(fx["traffic_multiplier"]) or float(fx["traffic_multiplier"]) < TRAFFIC_RANGE.x or float(fx["traffic_multiplier"]) > TRAFFIC_RANGE.y:
		errs.append("%s.traffic_multiplier: out_of_range" % path)
	if typeof(fx["category_weight_multipliers"]) != TYPE_DICTIONARY:
		errs.append("%s.category_weight_multipliers: not_object" % path)
		return errs
	for k in fx["category_weight_multipliers"]:
		var v = fx["category_weight_multipliers"][k]
		if not CATEGORIES.has(k) or not JsonCheck.is_number(v) or float(v) < CATEGORY_RANGE.x or float(v) > CATEGORY_RANGE.y:
			errs.append("%s.category_weight_multipliers.%s: invalid" % [path, k])
	return errs


## Events that may be drawn today, ordered by event_id.
static func candidates(events: Array, day_index: int, reputation: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in events:
		if day_index >= int(e["min_day_index"]) and reputation >= int(e["min_reputation"]):
			out.append(e)
	out.sort_custom(func(a, b): return a["event_id"] < b["event_id"])
	return out


## One draw: exactly one RNG step (also with no candidates). -> {"event_id": "" for none, "next_state", "roll", "total"}.
static func draw(events: Array, day_index: int, reputation: int, rng_state: int) -> Dictionary:
	var cands := candidates(events, day_index, reputation)
	var total := NONE_WEIGHT
	for e in cands:
		total += int(e["weight"])
	var rng := Lcg32.new(rng_state)
	var roll := rng.next_state() % total
	var acc := 0
	var chosen := ""
	for e in cands:
		acc += int(e["weight"])
		if roll < acc:
			chosen = e["event_id"]
			break
	return {"event_id": chosen, "next_state": rng.state, "roll": roll, "total": total}


## [start_sec, end_sec) of the event on `day_index`.
static func window(day_index: int, ev: Dictionary) -> Vector2i:
	var base := day_index * SECONDS_PER_DAY
	return Vector2i(base + int(ev["window_start_hour"]) * SECONDS_PER_HOUR, base + int(ev["window_end_hour"]) * SECONDS_PER_HOUR)


static func event_by_id(events: Array, event_id: String) -> Dictionary:
	for e in events:
		if e["event_id"] == event_id:
			return e
	return {}


## Multipliers in force at `time_sec`: {"traffic": float, "categories": {category: float}}. Neutral when
## nothing is active; started / ended are the saved flags, so a loaded game resumes exactly.
static func effects_at(events: Array, ges: Dictionary, time_sec: int) -> Dictionary:
	var neutral := {"traffic": 1.0, "categories": {}}
	if ges["selected_event_id"] == null or not bool(ges["started"]) or bool(ges["ended"]):
		return neutral
	if ges["event_start_sec"] == null or ges["event_end_sec"] == null or time_sec < int(ges["event_start_sec"]) or time_sec >= int(ges["event_end_sec"]):
		return neutral
	var ev := event_by_id(events, String(ges["selected_event_id"]))
	if ev.is_empty():
		return neutral
	return {"traffic": float(ev["effects"]["traffic_multiplier"]), "categories": ev["effects"]["category_weight_multipliers"].duplicate()}


static func category_multiplier(effects: Dictionary, category: String) -> float:
	return float(effects["categories"].get(category, 1.0))


static func notice_id(day_index: int, event_id: String, phase: String) -> String:
	return "daily:%d:%s:%s" % [day_index, event_id, phase]
