class_name EventService
extends RefCounted
## Runs the GameplayEventDirector against the game state (13 §3): the daily draw, start / end by the
## game clock, saved flags so a load or a same-day CLOSE -> OPEN never redraws or replays a notice.
## Does nothing when no event master data is loaded (old tests and saves stay as they were).
## Called once per fixed step before the arrival draw, so the effect of an event is seen by that step.


static func step(state: GameState) -> void:
	if state.gameplay_events.is_empty() or state.business_state != GameState.OPEN:
		return
	var day_index := state.time_sec / GameplayEventDirector.SECONDS_PER_DAY
	var ges := state.gameplay_event_state
	if day_index >= 1 and int(ges["last_selected_day"]) < day_index:
		_draw_today(state, day_index)
	if ges["selected_event_id"] == null:
		return
	var start := int(ges["event_start_sec"])
	var end := int(ges["event_end_sec"])
	if not bool(ges["started"]) and not bool(ges["ended"]):
		if state.time_sec >= end:
			ges["ended"] = true   # opened after the window: missed, recorded, never redrawn
		elif state.time_sec >= start:
			ges["started"] = true
			_announce(state, day_index, "started", "EVENT_STARTED")
	if bool(ges["started"]) and not bool(ges["ended"]) and state.time_sec >= end:
		ges["ended"] = true
		_announce(state, day_index, "ended", "EVENT_ENDED")


static func _draw_today(state: GameState, day_index: int) -> void:
	var ges := state.gameplay_event_state
	_remember(state)
	var r := GameplayEventDirector.draw(state.gameplay_events, day_index, state.reputation, int(state.rng_states["events"]))
	state.rng_states["events"] = r["next_state"]
	ges["last_selected_day"] = day_index
	ges["selection_event_id"] = "daily:%d" % day_index
	ges["started"] = false
	ges["ended"] = false
	ges["choice_id"] = null   # a new day's event is chosen afresh
	if r["event_id"] == "":
		ges["selected_event_id"] = null
		ges["event_start_sec"] = null
		ges["event_end_sec"] = null
		return
	var ev := GameplayEventDirector.event_by_id(state.gameplay_events, r["event_id"])
	var w := GameplayEventDirector.window(day_index, ev)
	ges["selected_event_id"] = r["event_id"]
	ges["event_start_sec"] = w.x
	ges["event_end_sec"] = w.y


## #31 イベント履歴: before a new day's draw replaces it, the last drawn day goes into state.event_history (held =
## its window started while open). At most HISTORY_DAYS entries are kept; a day is recorded once.
const HISTORY_DAYS := 30


static func _remember(state: GameState) -> void:
	var ges := state.gameplay_event_state
	var last := int(ges["last_selected_day"])
	if last < 1 or state.event_history.any(func(h): return int(h["day"]) == last):
		return
	state.event_history.append({"day": last, "event_id": String(ges["selected_event_id"]) if ges["selected_event_id"] != null else "",
		"held": bool(ges["started"])})
	while state.event_history.size() > HISTORY_DAYS:
		state.event_history.pop_front()


## イベント履歴 for the screen, newest first: {day, name_ja, held} (name_ja "" = no event that day).
static func history(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(state.event_history.size() - 1, -1, -1):
		var h: Dictionary = state.event_history[i]
		var ev := GameplayEventDirector.event_by_id(state.gameplay_events, String(h["event_id"])) if String(h["event_id"]) != "" else {}
		out.append({"day": int(h["day"]), "name_ja": String(ev.get("name_ja", "")), "held": bool(h["held"])})
	return out


## The notice id is `daily:<day>:<event>:<started|ended>`; a notice already in shown_notice_ids is not repeated.
static func _announce(state: GameState, day_index: int, phase: String, event_type: String) -> void:
	var ges := state.gameplay_event_state
	var id := GameplayEventDirector.notice_id(day_index, String(ges["selected_event_id"]), phase)
	if ges["shown_notice_ids"].has(id):
		return
	ges["shown_notice_ids"].append(id)
	var ev := GameplayEventDirector.event_by_id(state.gameplay_events, String(ges["selected_event_id"]))
	state.emit_event(event_type, {"event_id": ev["event_id"], "name_ja": ev["name_ja"], "window": "%02d:00-%02d:00" % [ev["window_start_hour"], ev["window_end_hour"]]}, id)


## #31 本日のイベント一覧: every event of the master data in data order, with what it means for today:
## state "selected" (today's draw), "candidate" (could be drawn today) or "locked" (lock: "DAY n から" / "評判 n 以上").
## Read only. Each entry: {event_id, name_ja, description_ja, start_hour, end_hour, traffic, categories, state, lock}.
static func catalog(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var day := state.time_sec / GameplayEventDirector.SECONDS_PER_DAY
	var v := view(state)
	var selected := String(v.get("event_id", "")) if String(v.get("status", "")) in ["scheduled", "active", "ended", "missed"] else ""
	for e in state.gameplay_events:
		var lock := ""
		if day < int(e["min_day_index"]):
			lock = "DAY %d から" % int(e["min_day_index"])
		elif state.reputation < int(e["min_reputation"]):
			lock = "評判 %d 以上" % int(e["min_reputation"])
		out.append({
			"event_id": e["event_id"], "name_ja": e["name_ja"], "description_ja": e["description_ja"],
			"start_hour": int(e["window_start_hour"]), "end_hour": int(e["window_end_hour"]),
			"traffic": float(e["effects"]["traffic_multiplier"]), "categories": e["effects"]["category_weight_multipliers"].duplicate(),
			"state": "selected" if e["event_id"] == selected else ("locked" if lock != "" else "candidate"), "lock": lock,
		})
	return out


## CHOOSE_EVENT_OPTION: the player's pick for today's event, once, before the event ends. A paid choice books its
## cost as a PROMO expense (販促費) now; nothing changes when the pick is refused. -> "" or the reason.
static func choose(state: GameState, command_id: String, choice_id: String) -> String:
	var v := view(state)
	if not String(v.get("status", "")) in ["scheduled", "active"]:
		return "no_event_to_choose"
	var ges := state.gameplay_event_state
	if ges.get("choice_id") != null:
		return "event_choice_made"
	var ev := GameplayEventDirector.event_by_id(state.gameplay_events, String(ges["selected_event_id"]))
	var c := GameplayEventDirector.choice_by_id(ev, choice_id)
	if c.is_empty():
		return "unknown_event_choice"
	var cost := int(c["cost_yen"])
	if cost > state.cash_yen:
		return "not_enough_cash"
	if cost > 0 and not state.ledger.record("PROMO", "%s:EVENT_CHOICE" % command_id, -cost, state.day, state.time_sec,
			{"event_id": ev["event_id"], "choice_id": choice_id}, {"expense": cost}):
		return "not_enough_cash"
	ges["choice_id"] = choice_id
	return ""


## Multipliers in force right now.
static func effects(state: GameState) -> Dictionary:
	return GameplayEventDirector.effects_at(state.gameplay_events, state.gameplay_event_state, state.time_sec)


## What the screen shows (SCR-11): {"status", "event_id", "name_ja", "description_ja", "start_sec", "end_sec", "traffic", "categories", "tone",
## "visual_theme", "choices", "choice_id"}. choices = [] for an event without; choice_id = "" until the player picks.
## status: no_data | undrawn | none | scheduled | active | ended | missed.
static func view(state: GameState) -> Dictionary:
	var ges := state.gameplay_event_state
	if state.gameplay_events.is_empty():
		return {"status": "no_data"}
	if int(ges["last_selected_day"]) < 0 or int(ges["last_selected_day"]) < state.time_sec / GameplayEventDirector.SECONDS_PER_DAY:
		return {"status": "undrawn", "day": state.time_sec / GameplayEventDirector.SECONDS_PER_DAY}
	if ges["selected_event_id"] == null:
		return {"status": "none", "day": int(ges["last_selected_day"])}
	var ev := GameplayEventDirector.event_by_id(state.gameplay_events, String(ges["selected_event_id"]))
	var status := "scheduled"
	if bool(ges["ended"]):
		status = "ended" if bool(ges["started"]) else "missed"
	elif bool(ges["started"]):
		status = "active"
	var fx: Dictionary = GameplayEventDirector.effective_choice(ev, ges).get("effects", ev["effects"])
	var choices: Array[Dictionary] = []
	for c in ev.get("choices", []):
		choices.append({"choice_id": c["choice_id"], "label_ja": c["label_ja"], "description_ja": c["description_ja"], "cost_yen": int(c["cost_yen"]),
			"traffic": float(c["effects"]["traffic_multiplier"]), "categories": c["effects"]["category_weight_multipliers"].duplicate(), "line_ja": c["line_ja"]})
	return {
		"status": status, "day": int(ges["last_selected_day"]), "event_id": ev["event_id"], "name_ja": ev["name_ja"], "description_ja": ev["description_ja"],
		"start_sec": int(ges["event_start_sec"]), "end_sec": int(ges["event_end_sec"]), "traffic": float(fx["traffic_multiplier"]),
		"categories": fx["category_weight_multipliers"].duplicate(), "tone": ev["tone"], "visual_theme": ev["visual_theme"],
		"choices": choices, "choice_id": "" if ges.get("choice_id") == null else String(ges["choice_id"]),
	}
