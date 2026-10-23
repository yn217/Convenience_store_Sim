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
	var r := GameplayEventDirector.draw(state.gameplay_events, day_index, state.reputation, int(state.rng_states["events"]))
	state.rng_states["events"] = r["next_state"]
	ges["last_selected_day"] = day_index
	ges["selection_event_id"] = "daily:%d" % day_index
	ges["started"] = false
	ges["ended"] = false
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


## The notice id is `daily:<day>:<event>:<started|ended>`; a notice already in shown_notice_ids is not repeated.
static func _announce(state: GameState, day_index: int, phase: String, event_type: String) -> void:
	var ges := state.gameplay_event_state
	var id := GameplayEventDirector.notice_id(day_index, String(ges["selected_event_id"]), phase)
	if ges["shown_notice_ids"].has(id):
		return
	ges["shown_notice_ids"].append(id)
	var ev := GameplayEventDirector.event_by_id(state.gameplay_events, String(ges["selected_event_id"]))
	state.emit_event(event_type, {"event_id": ev["event_id"], "name_ja": ev["name_ja"], "window": "%02d:00-%02d:00" % [ev["window_start_hour"], ev["window_end_hour"]]}, id)


## Multipliers in force right now.
static func effects(state: GameState) -> Dictionary:
	return GameplayEventDirector.effects_at(state.gameplay_events, state.gameplay_event_state, state.time_sec)


## What the screen shows (SCR-11): {"status", "event_id", "name_ja", "description_ja", "start_sec", "end_sec", "traffic", "categories", "tone"}.
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
	return {
		"status": status, "day": int(ges["last_selected_day"]), "event_id": ev["event_id"], "name_ja": ev["name_ja"], "description_ja": ev["description_ja"],
		"start_sec": int(ges["event_start_sec"]), "end_sec": int(ges["event_end_sec"]), "traffic": float(ev["effects"]["traffic_multiplier"]),
		"categories": ev["effects"]["category_weight_multipliers"].duplicate(), "tone": ev["tone"],
	}
