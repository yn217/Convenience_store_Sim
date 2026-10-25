class_name StaffMarket
extends RefCounted
## Hiring (issue #144, docs/design/CUSTOMER_STAFF_V2.md §4.4-4.5). Every morning three candidates are drawn from
## the archetypes in data/staff/archetypes_v1.json (weights, skill ranges, names) with the `staff` random stream,
## so the same seed always offers the same people. Hiring is limited by StaffAI.capacity (the staff room); a
## smaller room never fires anyone, it only stops hiring. The day's staffing figures (line length by hour, people
## who turned back or gave up, staff utilisation) are kept in state.staff_metrics for the 店員 tab and the advice.

const PATH := "res://data/staff/archetypes_v1.json"
const CANDIDATES_PER_DAY := 3

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"archetypes": [], "names": []}
	return _data


static func label(archetype: String) -> String:
	for a in data()["archetypes"]:
		if a["archetype"] == archetype:
			return String(a["label"])
	return archetype


## Today's candidates: CANDIDATES_PER_DAY people, each an archetype by weight, skills within its ranges and a name
## (all from the `staff` stream; ids cand_d<day>_<n>).
static func draw_candidates(state: GameState) -> void:
	var rng := Lcg32.new(int(state.rng_states.get("staff", 97531)))
	var archetypes: Array = data()["archetypes"]
	var names: Array = data()["names"]
	state.staff_candidates.clear()
	if archetypes.is_empty():
		return
	for i in CANDIDATES_PER_DAY:
		var total := 0.0
		for a in archetypes:
			total += float(a["weight"])
		var roll := rng.uniform_0_1() * total
		var chosen: Dictionary = archetypes[archetypes.size() - 1]
		var acc := 0.0
		for a in archetypes:
			acc += float(a["weight"])
			if roll < acc:
				chosen = a
				break
		var skills := {}
		for k in StaffAI.SKILLS:
			var r: Array = chosen["skills"][k]
			skills[k] = int(r[0]) + mini(int(rng.uniform_0_1() * float(int(r[1]) - int(r[0]) + 1)), int(r[1]) - int(r[0]))
		var name := String(names[int(rng.uniform_0_1() * names.size()) % names.size()]) if not names.is_empty() else "店員"
		state.staff_candidates.append({"candidate_id": "cand_d%03d_%d" % [state.day, i + 1], "name": name, "archetype": chosen["archetype"], "skills": skills})
	state.rng_states["staff"] = rng.state


## Hires a candidate. -> "" or an error key (unknown_candidate, staff_cap_reached).
static func hire(state: GameState, candidate_id: String) -> String:
	var idx := -1
	for i in state.staff_candidates.size():
		if state.staff_candidates[i]["candidate_id"] == candidate_id:
			idx = i
	if idx < 0:
		return "unknown_candidate"
	if state.staff.size() >= StaffAI.capacity(state):
		return "staff_cap_reached"
	var cand: Dictionary = state.staff_candidates[idx]
	state.staff.append(StaffAI.make(state, cand, state.grid.entrance_tiles[0]))
	state.staff_candidates.remove_at(idx)
	return ""


## Lets a staff member go. -> "" or "unknown_staff".
static func fire(state: GameState, staff_id: String) -> String:
	for i in state.staff.size():
		if state.staff[i]["staff_id"] == staff_id:
			state.staff.remove_at(i)
			return ""
	return "unknown_staff"


# ---------------------------------------------------------------- metrics

static func empty_metrics() -> Dictionary:
	var zeros := func(): var a: Array = []; a.resize(24); a.fill(0); return a
	return {"line_sum": zeros.call(), "line_steps": zeros.call(), "balked": zeros.call(), "abandoned": zeros.call(), "busy_steps": {}, "steps": 0}


## Called once per step (after the customers): the line at the register this hour and who is working.
static func record_step(state: GameState) -> void:
	var m: Dictionary = state.staff_metrics
	var h := DemandModel.hour_of_day(state.time_sec)
	var line := 0
	for c in state.customers:
		if c["phase"] in ["WAIT_QUEUE", "QUEUE", "CHECKOUT"]:
			line += 1
	m["line_sum"][h] = int(m["line_sum"][h]) + line
	m["line_steps"][h] = int(m["line_steps"][h]) + 1
	m["steps"] = int(m["steps"]) + 1
	for s in state.staff:
		if s["phase"] in ["REGISTER", "TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING"]:
			m["busy_steps"][s["staff_id"]] = int(m["busy_steps"].get(s["staff_id"], 0)) + 1


## Counts a customer who turned back at the door ("balked") or gave up in the line ("abandoned") this hour.
static func note(state: GameState, kind: String) -> void:
	var m: Dictionary = state.staff_metrics
	if m.is_empty() or not m.has(kind):
		return
	var h := DemandModel.hour_of_day(state.time_sec)
	m[kind][h] = int(m[kind][h]) + 1


## Average line length per hour (24 floats).
static func line_by_hour(m: Dictionary) -> Array:
	var out: Array = []
	for h in 24:
		var n := int(m.get("line_steps", [])[h]) if not m.is_empty() else 0
		out.append(0.0 if n == 0 else float(m["line_sum"][h]) / float(n))
	return out


## Share of today's steps a staff member spent working (register or restocking), 0..1.
static func utilisation(m: Dictionary, staff_id: String) -> float:
	var steps := int(m.get("steps", 0))
	return 0.0 if steps <= 0 else float(m.get("busy_steps", {}).get(staff_id, 0)) / float(steps)


## Advice for the 店員 tab, from today's figures (or yesterday's when today has none yet): the busiest hour's
## line, the people lost to the line, the staff cap. "" when there is nothing to say.
static func advice(state: GameState) -> String:
	var m: Dictionary = state.staff_metrics if int(state.staff_metrics.get("steps", 0)) > 0 else state.staff_metrics_yesterday
	if m.is_empty():
		return ""
	var lines := line_by_hour(m)
	var peak_h := 0
	for h in 24:
		if float(lines[h]) > float(lines[peak_h]):
			peak_h = h
	var lost := 0
	for h in 24:
		lost += int(m["balked"][h]) + int(m["abandoned"][h])
	var cap := StaffAI.capacity(state)
	if float(lines[peak_h]) < 1.5 and lost == 0:
		return "レジ待ちは落ち着いています。今の人数で足りています。"
	var spend := 0
	if not state.daily_reports.is_empty():
		var r: Dictionary = state.daily_reports.back()
		if int(r["purchasing_customers"]) > 0:
			spend = int(r["revenue_yen"]) / int(r["purchasing_customers"])
	var month := GameCalendar.days_per_month(state.balance)
	var text := "%d時台のレジ待ちが平均%.1f人、行列で帰った・入口で引き返した客が%d人。" % [peak_h, float(lines[peak_h]), lost]
	if spend > 0 and lost > 0:
		text += "取り戻せれば月%s円の売上の見込み（客単価%s円 × %d人 × %d日）。" % [_n(spend * lost * month), _n(spend), lost, month]
	if state.staff.size() < cap:
		text += "店員を1人増やすことを検討しましょう（あと%d人雇えます）。" % (cap - state.staff.size())
	else:
		text += "上限の%d人に達しています。大きい控え室を置くと、さらに雇えます。" % cap
	return text


static func _n(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
