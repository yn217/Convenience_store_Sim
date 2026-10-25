class_name StaffAI
extends RefCounted
## Store staff (issue #143, docs/design/CUSTOMER_STAFF_V2.md §4). Runs once per fixed step before the customers,
## staff in ascending id order, no random draws (the same state always gives the same moves).
##   - The register customers use (CustomerAI's register plan) is open only while a staff member stands at its
##     cashier cell, the tile behind the counter. The checkout time divides by that person's register factor.
##   - Staff with nothing else to do restock shelf slots below balance staff_restock_threshold: walk to the
##     pick-up point (the staff room's door tile, else the entrance), take up to the carry size, walk to the shelf
##     and put the units in (StockOps.restock, the same move as the player's RESTOCK).
##   - Fatigue 0..100 rises with work (scaled by stamina) and falls in the staff room. At the rest threshold a
##     person who is not needed at the register goes to rest; at 100 they must rest. Midnight resets it.
## A balance without staff_enabled keeps the old store: registers always open, no staff.

const PHASES := ["IDLE", "TO_REGISTER", "REGISTER", "TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING", "TO_REST", "REST"]
const SKILLS := ["register", "restock", "stamina", "service"]
const PICK_SEC := 20
const PUT_SEC_BASE := 40          # seconds to fill a slot at restock skill 3 (scaled by the skill factor)
const REST_UNTIL := 20.0          # a rest ends at this fatigue
const FORCED := 100.0

var _paths := PathService.new()


static func enabled(balance: Dictionary) -> bool:
	return bool(balance.get("staff_enabled", false))


## 0.8 .. 1.2 for skill 1 .. 5 (3 = 1.0).
static func skill_factor(skill: int) -> float:
	return 0.7 + 0.1 * float(clampi(skill, 1, 5))


## Work slows down as fatigue grows: -15 % from 70, -35 % from 90.
static func fatigue_factor(fatigue: float) -> float:
	if fatigue >= 90.0:
		return 0.65
	if fatigue >= 70.0:
		return 0.85
	return 1.0


## How many staff the store may employ: the placed staff room's staff_capacity, else balance
## staff_cap_without_room.
static func capacity(state: GameState) -> int:
	var cap := int(state.balance.get("staff_cap_without_room", 2))
	for inst in state.grid.instances.values():
		cap = maxi(cap, int(state.fixtures.get_type(inst["type_id"]).get("staff_capacity", 0)))
	return cap


## The placed staff room (instance id) or "".
static func staff_room(state: GameState) -> String:
	var ids := state.grid.instances.keys()
	ids.sort()
	for id in ids:
		if int(state.fixtures.get_type(state.grid.instances[id]["type_id"]).get("staff_capacity", 0)) > 0:
			return id
	return ""


## Daily wage of one person: balance staff_wage_base_yen + staff_wage_per_skill_yen x the sum of the four skills.
static func daily_wage(balance: Dictionary, s: Dictionary) -> int:
	var total := 0
	for k in SKILLS:
		total += int(s["skills"][k])
	return int(balance.get("staff_wage_base_yen", 0)) + int(balance.get("staff_wage_per_skill_yen", 0)) * total


## A new staff member from an archetype entry {name, skills}. Stands at `tile`.
static func make(state: GameState, entry: Dictionary, tile: Vector2i) -> Dictionary:
	state.next_staff_seq += 1
	var skills := {}
	for k in SKILLS:
		skills[k] = clampi(int(entry["skills"].get(k, 3)), 1, 5)
	return {
		"staff_id": "staff_%03d" % state.next_staff_seq, "name": String(entry.get("name", "店員")),
		"archetype": String(entry.get("archetype", "balanced")), "skills": skills, "fatigue": 0.0,
		"phase": "IDLE", "tile": tile, "path": [] as Array[Vector2i], "progress": 0.0, "timer": 0,
		"task": {}, "carry": 0, "trail": [], "moved": 0,
	}


# ---------------------------------------------------------------- per step

func step(state: GameState, register: Dictionary) -> void:
	if not enabled(state.balance) or state.staff.is_empty():
		return
	var ids: Array = state.staff.map(func(s): return s["staff_id"])
	ids.sort()
	var cashier_cell: Vector2i = register.get("cashier_cell", Vector2i(-1, -1))
	var on_register := ""   # who covers the register this step (walking there or standing at it)
	for s in state.staff:
		if s["phase"] in ["TO_REGISTER", "REGISTER"]:
			on_register = s["staff_id"] if on_register == "" or s["staff_id"] < on_register else on_register
	for id in ids:
		var s := _find(state, id)
		_tire(state, s)
		if s["phase"] in ["TO_REGISTER", "REGISTER"] and s["staff_id"] != on_register:
			s["phase"] = "IDLE"   # two on one register: the lower id keeps it
		_decide(state, s, register, cashier_cell, on_register)
		if s["phase"] in ["TO_REGISTER", "REGISTER"]:
			on_register = s["staff_id"]
		elif on_register == s["staff_id"]:
			on_register = ""
		_act(state, s, register, cashier_cell)


static func _find(state: GameState, id: String) -> Dictionary:
	for s in state.staff:
		if s["staff_id"] == id:
			return s
	return {}


## Fatigue per hour by activity (balance staff_fatigue_per_hour), scaled by stamina for work.
func _tire(state: GameState, s: Dictionary) -> void:
	var rates: Dictionary = state.balance.get("staff_fatigue_per_hour", {})
	var key := "idle"
	match String(s["phase"]):
		"REGISTER":
			key = "register"
		"TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING":
			key = "restock"
		"REST":
			key = "rest"
		"TO_REGISTER", "TO_REST":
			key = "walk"
	var rate := float(rates.get(key, 0.0))
	if key == "rest" and staff_room(state) == "":
		rate = 0.0   # no staff room: a pause, but no recovery until midnight
	if rate > 0.0:
		rate *= 1.0 / skill_factor(int(s["skills"]["stamina"]))   # stamina 5 tires 0.83x, stamina 1 1.25x
	s["fatigue"] = clampf(float(s["fatigue"]) + rate * GameClock.STEP_GAME_SECONDS / 3600.0, 0.0, FORCED)


## What the person should be doing now (only changes the phase and the route; _act moves).
func _decide(state: GameState, s: Dictionary, register: Dictionary, cashier_cell: Vector2i, on_register: String) -> void:
	var phase := String(s["phase"])
	var fatigue := float(s["fatigue"])
	var threshold := float(state.balance.get("staff_rest_threshold", 70))
	var busy_till := _checkout_running(state, String(register.get("register_id", "")))
	# Forced rest at 100 (except in the middle of a checkout at this register).
	if fatigue >= FORCED and not (phase == "REGISTER" and busy_till) and phase not in ["TO_REST", "REST"]:
		_go_rest(state, s)
		return
	if phase == "REST":
		if fatigue > REST_UNTIL and not (on_register == "" and _people_waiting(state) > 0 and fatigue < 90.0):
			return
		s["phase"] = "IDLE"
		phase = "IDLE"
	if phase == "REGISTER" or phase == "TO_REGISTER":
		# Hand over for a rest when someone else is free to take the till.
		if fatigue >= threshold and not busy_till and _someone_free(state, s, threshold):
			_go_rest(state, s)
		return
	if phase in ["TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING", "TO_REST"]:
		if on_register == "" and cashier_cell.x >= 0 and phase != "TO_REST" and int(s["carry"]) == 0:
			_go_register(state, s, cashier_cell)   # nobody at the till: drop the errand (nothing carried yet)
		return
	# IDLE: the till first, then rest when tired, then restocking, else wait.
	if on_register == "" and cashier_cell.x >= 0:
		_go_register(state, s, cashier_cell)
		return
	if fatigue >= threshold:
		_go_rest(state, s)
		return
	var task := _restock_task(state, s)
	if not task.is_empty():
		s["task"] = task
		_route(state, s, _pickup_tile(state), "TO_PICKUP")


func _act(state: GameState, s: Dictionary, register: Dictionary, cashier_cell: Vector2i) -> void:
	match String(s["phase"]):
		"TO_REGISTER":
			if _walk(state, s):
				s["phase"] = "REGISTER" if s["tile"] == cashier_cell else "IDLE"
		"TO_PICKUP":
			if _walk(state, s):
				s["phase"] = "PICKING"
				s["timer"] = PICK_SEC
		"PICKING":
			s["timer"] = int(s["timer"]) - int(GameClock.STEP_GAME_SECONDS)
			if int(s["timer"]) <= 0:
				var task: Dictionary = s["task"]
				s["carry"] = mini(carry_size(state.balance, s), mini(int(task["need"]), state.backroom_available(task["sku_id"])))
				if int(s["carry"]) <= 0 or not _route(state, s, task["access"], "TO_SHELF"):
					_drop_task(s)
		"TO_SHELF":
			if _walk(state, s):
				s["phase"] = "PUTTING"
				s["timer"] = int(ceil(float(PUT_SEC_BASE) / (skill_factor(int(s["skills"]["restock"])) * fatigue_factor(float(s["fatigue"])))))
		"PUTTING":
			s["timer"] = int(s["timer"]) - int(GameClock.STEP_GAME_SECONDS)
			if int(s["timer"]) <= 0:
				_put(state, s)
		"TO_REST":
			if _walk(state, s):
				s["phase"] = "REST"


## Units a person carries per trip: balance staff_carry_base + 2 x restock skill.
static func carry_size(balance: Dictionary, s: Dictionary) -> int:
	return int(balance.get("staff_carry_base", 4)) + 2 * int(s["skills"]["restock"])


func _put(state: GameState, s: Dictionary) -> void:
	var task: Dictionary = s["task"]
	var need := _slot_need(state, task["fixture_id"], task["slot"], task["sku_id"])
	var qty := mini(int(s["carry"]), mini(need, state.backroom_available(task["sku_id"])))
	if qty > 0:
		var r := StockOps.restock(state, "%s_t%d" % [s["staff_id"], state.time_sec], task["fixture_id"], task["slot"]["slot_id"], task["sku_id"], qty)
		if bool(r.get("ok", false)):
			state.emit_event("STAFF_RESTOCKED", {"staff_id": s["staff_id"], "fixture_id": task["fixture_id"], "sku_id": task["sku_id"], "qty": qty})
	_drop_task(s)


static func _drop_task(s: Dictionary) -> void:
	s["task"] = {}
	s["carry"] = 0
	s["phase"] = "IDLE"
	s["path"] = [] as Array[Vector2i]
	s["progress"] = 0.0


func _go_register(state: GameState, s: Dictionary, cashier_cell: Vector2i) -> void:
	_drop_task(s)
	if s["tile"] == cashier_cell:
		s["phase"] = "REGISTER"
	elif not _route(state, s, cashier_cell, "TO_REGISTER"):
		s["phase"] = "IDLE"


func _go_rest(state: GameState, s: Dictionary) -> void:
	_drop_task(s)
	var room := staff_room(state)
	if room == "":
		s["phase"] = "REST"   # no staff room: a short break where they stand (recovers only at midnight, see _tire)
		return
	if not _route(state, s, _pickup_tile(state), "TO_REST"):
		s["phase"] = "REST"


## Someone other than `me` who could take over the till (not resting, below the threshold).
func _someone_free(state: GameState, me: Dictionary, threshold: float) -> bool:
	for o in state.staff:
		if o["staff_id"] != me["staff_id"] and o["phase"] in ["IDLE", "TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING"] and float(o["fatigue"]) < threshold:
			return true
	return false


static func _checkout_running(state: GameState, register_id: String) -> bool:
	for c in state.customers:
		if c["phase"] == "CHECKOUT" and c["register_id"] == register_id:
			return true
	return false


static func _people_waiting(state: GameState) -> int:
	var n := 0
	for c in state.customers:
		if c["phase"] in ["WAIT_QUEUE", "QUEUE", "CHECKOUT"]:
			n += 1
	return n


## The emptiest slot below the threshold that has stock in the backroom and is not someone else's task.
## -> {fixture_id, slot (def), sku_id, need, access} or {}.
func _restock_task(state: GameState, s: Dictionary) -> Dictionary:
	var taken := {}
	for o in state.staff:
		if not (o["task"] as Dictionary).is_empty():
			taken["%s|%s" % [o["task"]["fixture_id"], o["task"]["slot"]["slot_id"]]] = true
	var threshold := float(state.balance.get("staff_restock_threshold", 0.5))
	var reach := _paths.current_distances(state.grid)
	var best := {}
	var best_fill := 2.0
	var ids := state.grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = state.grid.instances[id]
		var def := state.fixtures.get_type(inst["type_id"])
		if def["shelf_slots"].is_empty() or not inst.get("enabled", true):
			continue
		var access := AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach)
		if access.is_empty():
			continue
		for slot in def["shelf_slots"]:
			if taken.has("%s|%s" % [id, slot["slot_id"]]):
				continue
			var sku := _slot_sku(state, id, slot)
			if sku == "" or state.backroom_available(sku) <= 0:
				continue
			var cap := int(slot["capacity_units"]) / maxi(int(state.products.get_sku(sku)["slot_units"]), 1)
			var have := cap - _slot_need(state, id, slot, sku)
			var fill := float(have) / float(maxi(cap, 1))
			if fill < threshold and fill < best_fill:
				best_fill = fill
				best = {"fixture_id": id, "slot": slot, "sku_id": sku, "need": cap - have, "access": access[0]}
	return best


## The SKU a slot holds now, or for an empty slot the first SKU (by id) of its categories with backroom stock.
static func _slot_sku(state: GameState, fixture_id: String, slot: Dictionary) -> String:
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and loc["fixture_id"] == fixture_id and loc["slot_id"] == slot["slot_id"] and int(seg["physical_qty"]) > 0:
			return seg["sku_id"]
	var ids := state.products.skus.keys()
	ids.sort()
	for sku_id in ids:
		if slot["allowed_categories"].has(state.products.get_sku(sku_id)["category"]) and state.backroom_available(sku_id) > 0:
			return sku_id
	return ""


## Units of `sku_id` the slot can still take.
static func _slot_need(state: GameState, fixture_id: String, slot: Dictionary, sku_id: String) -> int:
	var units := maxi(int(state.products.get_sku(sku_id)["slot_units"]), 1)
	var used := 0
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and loc["fixture_id"] == fixture_id and loc["slot_id"] == slot["slot_id"]:
			used += int(seg["physical_qty"]) * units
	return maxi((int(slot["capacity_units"]) - used) / units, 0)


## Where staff pick up stock and rest: the staff room's first reachable door tile, else the first entrance.
func _pickup_tile(state: GameState) -> Vector2i:
	var room := staff_room(state)
	if room != "":
		var inst: Dictionary = state.grid.instances[room]
		var def := state.fixtures.get_type(inst["type_id"])
		var access := AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], _paths.current_distances(state.grid))
		if not access.is_empty():
			return access[0]
	return state.grid.entrance_tiles[0]


func _route(state: GameState, s: Dictionary, goal: Vector2i, phase: String) -> bool:
	if s["tile"] == goal:
		s["path"] = [] as Array[Vector2i]
		s["phase"] = phase
		return true
	var found := PathService.find_path(state.grid, state.grid.blocked_cells(), s["tile"], goal)
	if found.is_empty():
		return false
	found.pop_front()
	s["path"] = found
	s["progress"] = 0.0
	s["phase"] = phase
	return true


## Same walking as the customers (balance customer_walk_tiles_per_game_second x staff_walk_factor).
func _walk(state: GameState, s: Dictionary) -> bool:
	var path: Array = s["path"]
	var speed := float(state.balance.get("customer_walk_tiles_per_game_second", 0.6)) * float(state.balance.get("staff_walk_factor", 1.0))
	s["progress"] = float(s["progress"]) + speed * GameClock.STEP_GAME_SECONDS
	while float(s["progress"]) >= 1.0 and not path.is_empty():
		s["progress"] = float(s["progress"]) - 1.0
		s["tile"] = path.pop_front()
		var trail: Array = s["trail"]
		trail.append(s["tile"])
		if trail.size() > CustomerAI.TRAIL_MAX:
			trail.pop_front()
		s["moved"] = int(s["moved"]) + 1
	if path.is_empty():
		s["progress"] = 0.0
		return true
	return false


# ---------------------------------------------------------------- register side

## The tile behind the counter: the first in-store, unblocked cell on the side opposite the customers' access
## edge (the cashier stands there). (-1, -1) when there is none.
static func cashier_cell(state: GameState, register_id: String) -> Vector2i:
	if register_id == "" or not state.grid.instances.has(register_id):
		return Vector2i(-1, -1)
	var inst: Dictionary = state.grid.instances[register_id]
	var def := state.fixtures.get_type(inst["type_id"])
	if def["access_edges"].is_empty():
		return Vector2i(-1, -1)
	var back := def.duplicate()
	back["access_edges"] = [PlacementRules.rotate_edge(def["access_edges"][0], 2)]
	var blocked := state.grid.blocked_cells()
	for c in PlacementRules.access_candidates(back, inst["x"], inst["y"], inst["rotation"]):
		if state.grid.in_bounds(c) and not blocked.has(c):
			return c
	return Vector2i(-1, -1)


## The staff member standing at the register's cashier cell, or {} (the register is closed).
static func cashier(state: GameState, register_id: String) -> Dictionary:
	if not enabled(state.balance):
		return {"skills": {"register": 3}, "fatigue": 0.0}   # no staff model: always open, average speed
	for s in state.staff:
		if s["phase"] == "REGISTER":
			return s
	return {}


## Checkout seconds for `items` at this register now: the balance time / (register skill x fatigue factor).
static func checkout_seconds(state: GameState, register_id: String, items: int) -> int:
	var base := BasketModel.checkout_seconds(state.balance, items)
	var s := cashier(state, register_id)
	if s.is_empty() or not enabled(state.balance):
		return base
	return int(ceil(float(base) / (skill_factor(int(s["skills"]["register"])) * fatigue_factor(float(s["fatigue"])))))
