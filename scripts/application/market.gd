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

static var _data: Dictionary = {}


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
	if home.plot_id == "" or state.day < int(d["first_day"]):
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
	if rivals.is_empty():
		return 1.0
	var total := 0.0
	for r in rivals:
		total += rival_share(store, r, day)
	if total <= 0.0:
		return 1.0
	return 1.0 - minf(total, float(data()["total_cap"]))


## For the ライバル店 lines: every rival with its distance-weighted share of this store today.
static func views(store: GameState, rivals: Array, day: int) -> Array:
	return rivals.map(func(r): return {"rival_id": r["rival_id"], "name": r["name"], "opened_day": r["opened_day"], "map_id": r["map_id"], "x": r["x"], "y": r["y"],
		"share": snappedf(rival_share(store, r, day), 0.001), "on_sale": _on_sale(r, day)})
