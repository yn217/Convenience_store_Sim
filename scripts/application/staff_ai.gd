class_name StaffAI
extends RefCounted
## Store staff (issue #143, docs/design/CUSTOMER_STAFF_V2.md §4). Runs once per fixed step before the customers,
## staff in ascending id order, no random draws (the same state always gives the same moves).
##   - A register is open only while a staff member stands at its cashier cell, the tile behind the counter. The
##     checkout time divides by that person's register factor. The primary register (the first by instance id) is
##     always staffed; further registers open when the line grows beyond balance staff_customers_per_register per
##     open till (keeping one person on the floor) and close again once their own line is empty and the store is
##     quiet (registers_wanted). The free person nearest to a till that needs someone goes; customers pick the open
##     till with the shortest line and move over when another till opens (CustomerAI).
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
static var _cells: Dictionary = {}   # register id -> cashier cell for the layout in _cells_key
static var _cells_key := []
var _stock_index: Array = []   # restock candidates for one step (see _restock_candidates); rebuilt after a put
var _stock_index_key := []


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
		# staff ids are company-unique: a second store's people are "s2_staff_001" ... (#146)
		"staff_id": "%sstaff_%03d" % ["" if state.store_id == "" else state.store_id + "_", state.next_staff_seq], "name": String(entry.get("name", "店員")),
		"archetype": String(entry.get("archetype", "balanced")), "skills": skills, "fatigue": 0.0,
		"phase": "IDLE", "tile": tile, "path": [] as Array[Vector2i], "progress": 0.0, "timer": 0,
		"task": {}, "carry": 0, "trail": [], "moved": 0,
	}


# ---------------------------------------------------------------- per step

## `registers`: the usable registers, primary first, as {register_id, cashier_cell} (CustomerAI.register_plans_now);
## a single Dictionary is read as a one-register store.
func step(state: GameState, registers) -> void:
	if not enabled(state.balance) or state.staff.is_empty():
		return
	var regs: Array = []
	if typeof(registers) == TYPE_DICTIONARY:
		if String(registers.get("register_id", "")) != "":
			regs.append(registers)
	else:
		regs = (registers as Array).filter(func(r): return Vector2i(r.get("cashier_cell", Vector2i(-1, -1))).x >= 0)
	var ids: Array = state.staff.map(func(s): return s["staff_id"])
	ids.sort()
	var threshold := float(state.balance.get("staff_rest_threshold", 70))
	var ctx := {"regs": regs, "wanted": registers_wanted(state, regs), "covers": {}, "threshold": threshold}
	# Who covers each register this step (walking there or standing at it). A tired cashier waiting for relief keeps
	# the till open but does not count: the relief walks over and takes it.
	for s in state.staff:
		var i := station_of(s, regs)
		if i >= 0 and not _hands_over(state, s, threshold, regs):
			var rid: String = regs[i]["register_id"]
			if not ctx["covers"].has(rid) or s["staff_id"] < ctx["covers"][rid]:
				ctx["covers"][rid] = s["staff_id"]
	for id in ids:
		var s := _find(state, id)
		_tire(state, s)
		var before := station_of(s, regs)
		var handing_over := _hands_over(state, s, threshold, regs)
		if s["phase"] in ["TO_REGISTER", "REGISTER"] and not handing_over and (before < 0 or ctx["covers"].get(regs[before]["register_id"], "") != s["staff_id"]):
			s["phase"] = "IDLE"   # two on one register: the lower id keeps it (or the register is gone)
			s["path"] = [] as Array[Vector2i]
		_decide(state, s, ctx)
		if before >= 0 and ctx["covers"].get(regs[before]["register_id"], "") == s["staff_id"]:
			ctx["covers"].erase(regs[before]["register_id"])
		var after := station_of(s, regs)
		if after >= 0 and not (handing_over and s["phase"] == "REGISTER"):
			ctx["covers"][regs[after]["register_id"]] = s["staff_id"]
		_act(state, s, regs)


## Index in `regs` of the register a person stands at (REGISTER) or walks to (TO_REGISTER), else -1.
static func station_of(s: Dictionary, regs: Array) -> int:
	if not s["phase"] in ["REGISTER", "TO_REGISTER"]:
		return -1
	var at := target_tile(s)
	for i in regs.size():
		if regs[i]["cashier_cell"] == at:
			return i
	return -1


## Where a person ends up: the end of the route, or the tile they stand on.
static func target_tile(s: Dictionary) -> Vector2i:
	var path: Array = s["path"]
	return path.back() if not path.is_empty() else s["tile"]


## How many registers should be staffed now: one per balance staff_customers_per_register people heading for,
## waiting at or paying at the tills (at least the primary one). An extra till that is staffed stays wanted while
## the line would still fill the tills before it, so it does not open and close with every customer. Extra tills
## always leave one person on the floor: with two staff only the primary till opens (a soak run with two staff on
## two tills left shelves empty five times as long while the backroom was full).
static func registers_wanted(state: GameState, regs: Array) -> int:
	if regs.size() <= 1:
		return regs.size()
	var per := maxi(int(state.balance.get("staff_customers_per_register", 3)), 1)
	var waiting := 0
	for c in state.customers:
		if c["phase"] in ["WALK_REGISTER", "WAIT_QUEUE", "QUEUE", "CHECKOUT"]:
			waiting += 1
	var most := clampi(state.staff.size() - 1, 1, regs.size())
	var wanted := clampi(ceili(float(waiting) / float(per)), 1, most)
	var manned := 0
	for i in regs.size():
		for o in state.staff:
			if o["phase"] in ["REGISTER", "TO_REGISTER"] and target_tile(o) == regs[i]["cashier_cell"]:
				manned = i + 1
				break
	if manned > wanted and waiting >= (manned - 1) * per:
		wanted = mini(manned, most)
	return wanted


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
	# Kept to 4 decimals so a save writes it exactly (JSON keeps 15 significant digits).
	s["fatigue"] = snappedf(clampf(float(s["fatigue"]) + rate * GameClock.STEP_GAME_SECONDS / 3600.0, 0.0, FORCED), 0.0001)


## What the person should be doing now (only changes the phase and the route; _act moves).
func _decide(state: GameState, s: Dictionary, ctx: Dictionary) -> void:
	var regs: Array = ctx["regs"]
	var phase := String(s["phase"])
	var fatigue := float(s["fatigue"])
	var threshold: float = ctx["threshold"]
	var at := station_of(s, regs)
	var rid: String = regs[at]["register_id"] if at >= 0 else ""
	var busy_till := at >= 0 and _checkout_running(state, rid)
	# Forced rest at 100 (except in the middle of a checkout at this register).
	if fatigue >= FORCED and not (phase == "REGISTER" and busy_till) and phase not in ["TO_REST", "REST"]:
		_go_rest(state, s)
		return
	if phase == "REST":
		var primary_open: bool = regs.is_empty() or ctx["covers"].has(regs[0]["register_id"])
		if fatigue > REST_UNTIL and not (not primary_open and _people_waiting(state) > 0 and fatigue < 90.0):
			return
		s["phase"] = "IDLE"
		phase = "IDLE"
	if phase == "TO_REGISTER":
		if fatigue >= threshold and _someone_free(state, s, threshold):
			_go_rest(state, s)   # not at the till yet: someone fresher goes instead
		elif at > 0 and at >= int(ctx["wanted"]) and CustomerAI.line_load(state, rid) == 0:
			_drop_task(s)   # the extra till is not needed any more
		return
	if phase == "REGISTER":
		# Hand over for a rest: stay at the till until the relief stands at this till and the checkout is done, so
		# the register never closes for the handover.
		if _hands_over(state, s, threshold, regs) and not busy_till and _relief_at(state, s, threshold, regs, at, ["REGISTER"]):
			_go_rest(state, s)
		elif at > 0 and at >= int(ctx["wanted"]) and CustomerAI.line_load(state, rid) == 0:
			_drop_task(s)   # an extra till closes once its own line is empty and the store is quiet
		return
	var target := _open_target(ctx)
	if not target.is_empty() and not _nearest_free(state, s, target["cashier_cell"]):
		target = {}   # someone closer and free goes (this step, in their turn)
	if phase in ["TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING", "TO_REST"]:
		if not target.is_empty() and phase != "TO_REST" and int(s["carry"]) == 0:
			_go_register(state, s, target["cashier_cell"])   # a till needs someone: drop the errand (nothing carried yet)
		return
	# IDLE: a till that needs someone first, then rest when tired, then restocking, else wait.
	if not target.is_empty():
		_go_register(state, s, target["cashier_cell"])
		return
	if fatigue >= threshold:
		_go_rest(state, s)
		return
	var task := _restock_task(state, s)
	if not task.is_empty():
		s["task"] = task
		_route(state, s, _pickup_tile(state), "TO_PICKUP")


## Is `s` the free person nearest to `cell` (grid distance, then the lower id)? Free: idle, or on
## a restocking errand with nothing carried yet.
func _nearest_free(state: GameState, s: Dictionary, cell: Vector2i) -> bool:
	var mine := _floor_distance(state, s["tile"], cell)
	for o in state.staff:
		if o["staff_id"] == s["staff_id"] or float(o["fatigue"]) >= FORCED:
			continue
		var free: bool = o["phase"] == "IDLE" or (o["phase"] in ["TO_PICKUP", "PICKING", "TO_SHELF", "PUTTING"] and int(o["carry"]) == 0)
		if not free:
			continue
		var theirs := _floor_distance(state, o["tile"], cell)
		if theirs < mine or (theirs == mine and o["staff_id"] < s["staff_id"]):
			return false
	return true


## Grid distance between two tiles.
static func _floor_distance(_state: GameState, a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## The first wanted register nobody covers ({} when every wanted till has someone).
static func _open_target(ctx: Dictionary) -> Dictionary:
	var regs: Array = ctx["regs"]
	for i in mini(int(ctx["wanted"]), regs.size()):
		if not ctx["covers"].has(regs[i]["register_id"]):
			return regs[i]
	return {}


func _act(state: GameState, s: Dictionary, regs: Array) -> void:
	match String(s["phase"]):
		"TO_REGISTER":
			if _walk(state, s):
				s["phase"] = "REGISTER" if regs.any(func(r): return r["cashier_cell"] == s["tile"]) else "IDLE"
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
			_stock_index_key = []   # the shelves changed
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


## A tired cashier who has someone to hand the till to: a free person below the threshold, or someone fresher
## already walking to this till or standing at it.
func _hands_over(state: GameState, s: Dictionary, threshold: float, regs: Array) -> bool:
	if s["phase"] != "REGISTER" or float(s["fatigue"]) < threshold:
		return false
	var at := station_of(s, regs)
	return _someone_free(state, s, threshold) or (at >= 0 and _relief_at(state, s, threshold, regs, at, ["TO_REGISTER", "REGISTER"]))


## Someone else below the threshold at (or walking to) register `at`, in one of `phases`.
static func _relief_at(state: GameState, me: Dictionary, threshold: float, regs: Array, at: int, phases: Array) -> bool:
	if at < 0:
		return false
	for o in state.staff:
		if o["staff_id"] != me["staff_id"] and o["phase"] in phases and float(o["fatigue"]) < threshold and station_of(o, regs) == at:
			return true
	return false


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
	var best := {}
	var best_fill := 2.0
	for c in _restock_candidates(state):
		if float(c["fill"]) < best_fill and not taken.has(c["key"]):
			best_fill = float(c["fill"])
			best = c["task"]
	return best


## Every shelf slot below the restock threshold that the backroom can refill and staff can reach, in instance and
## slot order: {key "fixture|slot", fill, task {fixture_id, slot, sku_id, need, access}}. The slot's SKU is the one on
## it, or for an empty slot the first SKU (by id) of its categories with backroom stock (as _slot_sku); the need is
## _slot_need. Every idle person asks every step, so the list is kept until the stock changes: a sale, an expiry or
## a delivery moves the shelf or backroom totals, a command bumps the state revision, a put clears the key.
func _restock_candidates(state: GameState) -> Array:
	var on_shelves := 0
	var in_backroom := 0
	for seg in state.inventory_segments:
		if seg["location"]["kind"] == "FIXTURE":
			on_shelves += int(seg["physical_qty"])
		else:
			in_backroom += int(seg["physical_qty"]) - int(seg["reserved_qty"])
	var key := [state.revision, state.grid.revision, state.inventory_segments.size(), on_shelves, in_backroom]
	if key == _stock_index_key:
		return _stock_index
	var on_slot := {}     # "fixture|slot" -> [units on it, sku of its first stocked segment]
	var backroom := {}    # sku -> what the backroom can give
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE":
			var k := "%s|%s" % [loc["fixture_id"], loc["slot_id"]]
			var row: Array = on_slot.get(k, [0, ""])
			row[0] = int(row[0]) + int(seg["physical_qty"])
			if row[1] == "" and int(seg["physical_qty"]) > 0:
				row[1] = seg["sku_id"]
			on_slot[k] = row
		elif loc["kind"] == "BACKROOM":
			backroom[seg["sku_id"]] = int(backroom.get(seg["sku_id"], 0)) + int(seg["physical_qty"]) - int(seg["reserved_qty"])
	var sku_ids := state.products.skus.keys()
	sku_ids.sort()
	var first_of := {}    # category -> its first SKU (by id) with backroom stock
	for sid in sku_ids:
		var cat: String = state.products.get_sku(sid)["category"]
		if not first_of.has(cat) and int(backroom.get(sid, 0)) > 0:
			first_of[cat] = sid
	var threshold := float(state.balance.get("staff_restock_threshold", 0.5))
	var reach := _paths.current_distances(state.grid)
	var out: Array = []
	var ids := state.grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = state.grid.instances[id]
		var def := state.fixtures.get_type(inst["type_id"])
		if def["shelf_slots"].is_empty() or not inst.get("enabled", true):
			continue
		var access: Array[Vector2i] = []
		for slot in def["shelf_slots"]:
			var k := "%s|%s" % [id, slot["slot_id"]]
			var row: Array = on_slot.get(k, [0, ""])
			var sku: String = row[1]
			if sku == "":
				for cat in slot["allowed_categories"]:
					var sid: String = first_of.get(cat, "")
					if sid != "" and (sku == "" or sid < sku):
						sku = sid
			if sku == "" or int(backroom.get(sku, 0)) <= 0:
				continue
			var units := maxi(int(state.products.get_sku(sku)["slot_units"]), 1)
			var cap := int(slot["capacity_units"]) / units
			var need := maxi((int(slot["capacity_units"]) - int(row[0]) * units) / units, 0)
			var fill := float(cap - need) / float(maxi(cap, 1))
			if fill >= threshold:
				continue
			if access.is_empty():
				access = AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach)
				if access.is_empty():
					break
			out.append({"key": k, "fill": fill, "task": {"fixture_id": id, "slot": slot, "sku_id": sku, "need": need, "access": access[0]}})
	_stock_index = out
	_stock_index_key = key
	return out


## The SKU a slot holds now, or for an empty slot the first SKU (by id) of its categories with backroom stock.
static func _slot_sku(state: GameState, fixture_id: String, slot: Dictionary) -> String:
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if (loc["kind"] == "FIXTURE" or loc["kind"] == "OVEN") and loc["fixture_id"] == fixture_id and loc["slot_id"] == slot["slot_id"] and int(seg["physical_qty"]) > 0:
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
		if (loc["kind"] == "FIXTURE" or loc["kind"] == "OVEN") and loc["fixture_id"] == fixture_id and loc["slot_id"] == slot["slot_id"]:
			used += int(seg["physical_qty"]) * units   # a lot in the oven fills its tray too (#130)
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
	var cell := cashier_cell_cached(state, register_id)
	for s in state.staff:
		if s["phase"] == "REGISTER" and s["tile"] == cell:
			return s
	return {}


## cashier_cell, remembered per layout (customers ask for every waiting person every step).
static func cashier_cell_cached(state: GameState, register_id: String) -> Vector2i:
	var key := [state.grid.get_instance_id(), state.grid.revision, state.grid.instances.size()]
	if key != _cells_key:
		_cells.clear()
		_cells_key = key
	if not _cells.has(register_id):
		_cells[register_id] = cashier_cell(state, register_id)
	return _cells[register_id]


## Checkout seconds for `items` at this register now: the balance time / (register skill x fatigue factor).
static func checkout_seconds(state: GameState, register_id: String, items: int) -> int:
	var base := BasketModel.checkout_seconds(state.balance, items)
	var s := cashier(state, register_id)
	if s.is_empty() or not enabled(state.balance):
		return base
	return int(ceil(float(base) / (skill_factor(int(s["skills"]["register"])) * fatigue_factor(float(s["fatigue"])))))
