class_name Market
extends RefCounted
## Rival stores, phase 1 (issue #129, data/market/rivals_v1.json). A rival opens on a free site of the map of the
## company's first store — the free site nearest to it — from first_day, then every interval_days, at most
## max_rivals; nothing is drawn at random. A rival takes a share of a store's potential visitors that is largest
## right after it opens and settles down (peak -> floor over settle_days), more while it runs a sale (every
## sale_every_days for sale_days, announced as news), and less the farther away it is (nothing beyond reach_share of
## the map width); all rivals together take at most total_cap. A store without a map site has no rivals near it.
## The rivals are the company's (state.rivals, shared like the achievements); they can be switched off.

const PATH := "res://data/market/rivals_v1.json"

const CONDITIONS_PATH := "res://data/market/conditions_v1.json"

static var _data: Dictionary = {}
static var _cond: Dictionary = {}


## Local conditions (#129 phase 2, data/market/conditions_v1.json).
static func conditions_data() -> Dictionary:
	if _cond.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONDITIONS_PATH))
		_cond = parsed if typeof(parsed) == TYPE_DICTIONARY else {"conditions": []}
	return _cond


static func condition(condition_id: String) -> Dictionary:
	for c in conditions_data()["conditions"]:
		if c["condition_id"] == condition_id:
			return c
	return {}


## The conditions in force on `day` (a permanent one has end_day -1).
static func active_conditions(conditions: Array, day: int) -> Array:
	return conditions.filter(func(c): return int(c["start_day"]) <= day and (int(c["end_day"]) < 0 or day <= int(c["end_day"])))


## Local conditions (#129 phase 2): from first_day, every every_days the next one of the list starts for the
## company and lasts its days (a permanent one only once). No random draws.
static func _conditions_day(state: GameState) -> void:
	var cd := conditions_data()
	var list: Array = cd["conditions"]
	var since := state.day - int(cd["first_day"])
	if list.is_empty() or since < 0 or since % int(cd["every_days"]) != 0:
		return
	var c: Dictionary = list[(since / int(cd["every_days"])) % list.size()]
	if int(c["days"]) == 0 and state.market_conditions.any(func(x): return x["condition_id"] == c["condition_id"]):
		return   # a permanent change happens once
	state.market_conditions.append({"condition_id": c["condition_id"], "start_day": state.day, "end_day": -1 if int(c["days"]) == 0 else state.day + int(c["days"]) - 1})
	state.emit_event("CONDITION_STARTED", {"condition_id": c["condition_id"], "name_ja": c["name_ja"], "note": c["note"]})


## Multiplier of the conditions in force on visitors (1 without).
static func condition_factor(conditions: Array, day: int) -> float:
	var k := 1.0
	for c in active_conditions(conditions, day):
		k *= float(condition(c["condition_id"]).get("visitors", 1.0))
	return k


## Pull of a category from the conditions in force (1 without).
static func condition_category(conditions: Array, day: int, category: String) -> float:
	var k := 1.0
	for c in active_conditions(conditions, day):
		k *= float((condition(c["condition_id"]).get("categories", {}) as Dictionary).get(category, 1.0))
	return k


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"max_rivals": 0}
	return _data


## Called once for the store on screen at each new day: a rival may open, sales start and end.
static func on_new_day(state: GameState) -> void:
	if not state.rivals_enabled:
		return
	var d := data()
	var home := _home(state)
	if home.plot_id == "":
		return
	_conditions_day(state)
	if state.day < int(d["first_day"]):
		return
	for r in state.rivals:
		if _on_sale(r, state.day) and not _on_sale(r, state.day - 1):
			state.emit_event("RIVAL_SALE", {"rival_id": r["rival_id"], "name": r["name"]})
	var due := int(d["first_day"]) + int(d["interval_days"]) * state.rivals.size()
	if state.rivals.size() >= int(d["max_rivals"]) or state.day < due:
		return
	var site := _free_site_near(state, home)
	if site.is_empty():
		return
	var chains: Array = d["chains"]
	var r := {"rival_id": "rival_%02d" % (state.rivals.size() + 1), "name": "%s %s店" % [chains[state.rivals.size() % chains.size()], site["name"]],
		"map_id": home.map_id, "plot_id": site["id"], "x": float(site["x"]), "y": float(site["y"]), "opened_day": state.day}
	state.rivals.append(r)
	state.emit_event("RIVAL_OPENED", {"rival_id": r["rival_id"], "name": r["name"]})


## The first store of the company (its map site is where rivals come).
static func _home(state: GameState) -> GameState:
	for s in Company.stores(state):
		if s.store_id == "":
			return s
	return state


static func _free_site_near(state: GameState, home: GameState) -> Dictionary:
	var used := Company.used_sites(state)
	for r in state.rivals:
		used["%s|%s" % [r["map_id"], r["plot_id"]]] = r["rival_id"]
	var me := WorldMap.plot(home.map_id, home.plot_id)
	var best := {}
	var best_d := INF
	for p in WorldMap.load_map(home.map_id).get("plots", []):
		if used.has("%s|%s" % [home.map_id, p["id"]]) or WorldMap.plot_status(p) == "locked":
			continue
		var dist := Vector2(float(p["x"]) - float(me["x"]), float(p["y"]) - float(me["y"])).length()
		if dist < best_d:
			best_d = dist
			best = p
	return best


static func _on_sale(r: Dictionary, day: int) -> bool:
	var d := data()
	var since := day - int(r["opened_day"])
	return since > 0 and since % int(d["sale_every_days"]) < int(d["sale_days"])


## Share of a store's visitors one rival takes on `day` (0 when far, on another map, or for a store without a site).
static func rival_share(store: GameState, r: Dictionary, day: int) -> float:
	if store.plot_id == "" or store.map_id != r["map_id"] or day < int(r["opened_day"]):
		return 0.0
	var d := data()
	var me := WorldMap.plot(store.map_id, store.plot_id)
	var dist := Vector2(float(me["x"]) - float(r["x"]), float(me["y"]) - float(r["y"])).length()
	var falloff := maxf(0.0, 1.0 - dist / (float(d["reach_share"]) * WorldMap.map_size(store.map_id).x))
	var days := float(day - int(r["opened_day"]))
	var share := float(d["floor_share"]) + (float(d["peak_share"]) - float(d["floor_share"])) * exp(-days / float(d["settle_days"]))
	if _on_sale(r, day):
		share += float(d["sale_bonus"])
	return share * falloff


## Multiplier on a store's potential visitors today: 1 - (all rivals' shares, at most total_cap). Exactly 1 without
## rivals near.
static func visitor_factor(store: GameState, rivals: Array, day: int) -> float:
	var cond := condition_factor(store.market_conditions, day) if not store.market_conditions.is_empty() else 1.0
	if rivals.is_empty() and cond == 1.0:
		return 1.0
	var total := 0.0
	for r in rivals:
		total += rival_share(store, r, day)
	if total <= 0.0 and cond == 1.0:
		return 1.0
	var cd := conditions_data()
	return clampf((1.0 - minf(total, float(data()["total_cap"]))) * cond, float(cd.get("floor", 0.6)), float(cd.get("ceiling", 1.4)))


## For the 地域の動き lines: the conditions in force with days left (-1 = permanent).
static func condition_views(conditions: Array, day: int) -> Array:
	return active_conditions(conditions, day).map(func(c):
		var d := condition(c["condition_id"])
		return {"condition_id": c["condition_id"], "name_ja": d.get("name_ja", ""), "note": d.get("note", ""), "visitors": float(d.get("visitors", 1.0)),
			"days_left": -1 if int(c["end_day"]) < 0 else int(c["end_day"]) - day + 1})


## For the ライバル店 lines: every rival with its distance-weighted share of this store today.
static func views(store: GameState, rivals: Array, day: int) -> Array:
	return rivals.map(func(r): return {"rival_id": r["rival_id"], "name": r["name"], "opened_day": r["opened_day"], "map_id": r["map_id"], "x": r["x"], "y": r["y"],
		"share": snappedf(rival_share(store, r, day), 0.001), "on_sale": _on_sale(r, day)})
