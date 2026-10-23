class_name CustomerAI
extends RefCounted
## Customer state machine (03 §D, 09 §3): SELECT -> WALK_SHELF -> (pick = reserve) ->
## WALK_REGISTER -> QUEUE -> EXIT. Runs once per fixed step, customers in ascending id order,
## so the same seeds and ticks always give the same walks and purchases. Checkout and queue
## timeouts belong to M3-03/04; here a customer that reaches the queue waits there.
## RNG use: `purchases` only — one draw to pick the shelf item, one for the buy decision
## (a single draw when there is no candidate at all).

const WALK_TILES_PER_STEP_FALLBACK := 0.6
const RESERVATION_HOLD_SEC := 600
const MAX_RESELECT := 2

var _paths := PathService.new()


func step(state: GameState) -> void:
	_spawn(state)
	var ids: Array[String] = []
	for c in state.customers:
		ids.append(c["customer_id"])
	ids.sort()
	for id in ids:
		var c := _find(state, id)
		if not c.is_empty():
			_update(state, c)
	var alive: Array[Dictionary] = []
	for c in state.customers:
		if c["phase"] != "GONE":
			alive.append(c)
	state.customers = alive


# ---------------------------------------------------------------- spawn / helpers

func _spawn(state: GameState) -> void:
	for arrival in state.arrival_queue:
		var entrances := state.grid.entrance_tiles
		var tile: Vector2i = entrances[int(String(arrival["customer_id"]).right(5).to_int()) % entrances.size()]
		state.customers.append({
			"customer_id": arrival["customer_id"], "phase": "SELECT", "tile": tile, "path": [] as Array[Vector2i],
			"progress": 0.0, "fixture_id": "", "sku_id": "", "reservation_id": "", "queue_slot": -1, "retries": 0,
			"outcome": "",
		})
	state.arrival_queue.clear()


func _find(state: GameState, id: String) -> Dictionary:
	for c in state.customers:
		if c["customer_id"] == id:
			return c
	return {}


func _update(state: GameState, c: Dictionary) -> void:
	match c["phase"]:
		"SELECT":
			_select(state, c)
		"WALK_SHELF":
			if _walk(state, c):
				_pick(state, c)
		"WALK_REGISTER":
			if _reservation_lost(state, c):
				_leave(state, c, "reservation_lost")
			elif _walk(state, c):
				c["phase"] = "QUEUE"
		"QUEUE":
			if _reservation_lost(state, c):
				_leave(state, c, "reservation_lost")
		"EXIT":
			if _walk(state, c):
				c["phase"] = "GONE"


## Moves along the path by this step's walking budget. True once the path is finished.
func _walk(state: GameState, c: Dictionary) -> bool:
	var path: Array = c["path"]
	var speed: float = float(state.balance.get("customer_walk_tiles_per_game_second", WALK_TILES_PER_STEP_FALLBACK))
	c["progress"] = float(c["progress"]) + speed * GameClock.STEP_GAME_SECONDS
	while float(c["progress"]) >= 1.0 and not path.is_empty():
		c["progress"] = float(c["progress"]) - 1.0
		c["tile"] = path.pop_front()
	if path.is_empty():
		c["progress"] = 0.0
		return true
	return false


func _route(state: GameState, c: Dictionary, goal: Vector2i) -> bool:
	var found := PathService.find_path(state.grid, state.grid.blocked_cells(), c["tile"], goal)
	if found.is_empty():
		return false
	found.pop_front()   # already standing on the first tile
	c["path"] = found
	c["progress"] = 0.0
	return true


func _reservation_lost(state: GameState, c: Dictionary) -> bool:
	if c["reservation_id"] == "":
		return false
	for r in state.reservations:
		if r["reservation_id"] == c["reservation_id"]:
			return false
	return true


## Leaves the store: the reservation (if any) goes back to the shelf, stock stays untouched.
func _leave(state: GameState, c: Dictionary, outcome: String) -> void:
	if c["reservation_id"] != "":
		InventoryService.release_reservation(state, c["reservation_id"])
		c["reservation_id"] = ""
	c["queue_slot"] = -1
	c["outcome"] = outcome
	var reach := _paths.current_distances(state.grid)
	var goal := Vector2i(-1, -1)
	var best := 1 << 30
	for e in state.grid.entrance_tiles:
		var path := PathService.find_path(state.grid, state.grid.blocked_cells(), c["tile"], e)
		if not path.is_empty() and path.size() < best:
			best = path.size()
			goal = e
	if goal == Vector2i(-1, -1) or reach.is_empty():
		c["phase"] = "GONE"   # no way out is modelled as vanishing at the spot
		return
	c["phase"] = "EXIT"
	_route(state, c, goal)


# ---------------------------------------------------------------- SELECT

func _select(state: GameState, c: Dictionary) -> void:
	var cands := candidates(state)
	var rng := Lcg32.new(int(state.rng_states["purchases"]))
	if cands.is_empty():
		rng.next_state()   # a draw is consumed even without candidates (09 §3)
		state.rng_states["purchases"] = rng.state
		_leave(state, c, "no_candidate")
		return
	var total := 0.0
	for k in cands:
		total += k["weight"]
	var pick := rng.uniform_0_1() * total
	var chosen: Dictionary = cands[cands.size() - 1]
	var acc := 0.0
	for k in cands:
		acc += k["weight"]
		if pick < acc:
			chosen = k
			break
	var price_factor := _price_factor(state, chosen["sku_id"])
	var buy_p := clampf(0.80 * price_factor, 0.05, 0.95)
	var buys := rng.uniform_0_1() < buy_p
	state.rng_states["purchases"] = rng.state
	if not buys:
		_leave(state, c, "declined")
		return
	var inst: Dictionary = state.grid.instances[chosen["fixture_id"]]
	var def := state.fixtures.get_type(inst["type_id"])
	var reach := _paths.current_distances(state.grid)
	var access := AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach)
	c["fixture_id"] = chosen["fixture_id"]
	c["sku_id"] = chosen["sku_id"]
	if access.is_empty() or not _route(state, c, access[0]):
		_leave(state, c, "unreachable")
		return
	c["phase"] = "WALK_SHELF"


func _price_factor(state: GameState, sku_id: String) -> float:
	var ref := float(state.products.get_sku(sku_id)["default_sell_price_yen"])
	return clampf(ref / float(maxi(state.sell_price(sku_id), 1)), 0.3, 2.0)


## (sku_id, fixture_id) pairs a customer could buy right now, sorted by sku then fixture id,
## with weight = availability * accessibility * preference * appeal * demand_weight * price_factor.
func candidates(state: GameState) -> Array[Dictionary]:
	var reach := _paths.current_distances(state.grid)
	var seen := {}
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] != "FIXTURE" or InventoryService.is_expired(seg, state.time_sec):
			continue
		if int(seg["physical_qty"]) - int(seg["reserved_qty"]) < 1 or not state.grid.instances.has(loc["fixture_id"]):
			continue
		var inst: Dictionary = state.grid.instances[loc["fixture_id"]]
		if not inst.get("enabled", true):
			continue
		var def := state.fixtures.get_type(inst["type_id"])
		if AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach).is_empty():
			continue
		seen["%s|%s" % [seg["sku_id"], loc["fixture_id"]]] = {"sku_id": seg["sku_id"], "fixture_id": loc["fixture_id"]}
	var keys := seen.keys()
	keys.sort()
	var out: Array[Dictionary] = []
	for k in keys:
		var e: Dictionary = seen[k]
		e["weight"] = float(state.products.get_sku(e["sku_id"])["demand_weight"]) * _price_factor(state, e["sku_id"])
		out.append(e)
	return out


# ---------------------------------------------------------------- PICK / register

func _pick(state: GameState, c: Dictionary) -> void:
	var res := InventoryService.reserve(state, "res_%s_%d" % [c["customer_id"], c["retries"]], c["customer_id"], c["sku_id"], RESERVATION_HOLD_SEC, c["fixture_id"])
	if res.is_empty():
		c["retries"] = int(c["retries"]) + 1
		if int(c["retries"]) > MAX_RESELECT:
			_leave(state, c, "stockout")
		else:
			c["phase"] = "SELECT"
		return
	c["reservation_id"] = res["reservation_id"]
	var plan := _register_plan(state)
	if plan.is_empty():
		_leave(state, c, "no_register")
		return
	var taken := {}
	for other in state.customers:
		if other["customer_id"] != c["customer_id"] and int(other["queue_slot"]) >= 0:
			taken[int(other["queue_slot"])] = true
	var slot := -1
	for i in plan["queue_cells"].size():
		if not taken.has(i):
			slot = i
			break
	if slot < 0:
		_leave(state, c, "queue_full")
		return
	c["queue_slot"] = slot
	if not _route(state, c, plan["queue_cells"][slot]):
		_leave(state, c, "unreachable_register")
		return
	c["phase"] = "WALK_REGISTER"


## First register (by instance id) that can form a queue: {service_cell, queue_cells} or {}.
func _register_plan(state: GameState) -> Dictionary:
	var reach := _paths.current_distances(state.grid)
	var blocked := state.grid.blocked_cells()
	var ids := state.grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = state.grid.instances[id]
		var def := state.fixtures.get_type(inst["type_id"])
		if not AccessService.is_register(def) or not inst.get("enabled", true):
			continue
		var plan := AccessService.register_plan(state.grid, def, inst["x"], inst["y"], inst["rotation"], blocked, reach)
		if int(plan["slots"]) > 0:
			return plan
	return {}
