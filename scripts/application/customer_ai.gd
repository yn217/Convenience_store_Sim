class_name CustomerAI
extends RefCounted
## Customer state machine (03 §D, 09 §3): SELECT -> WALK_SHELF -> (pick = reserve) -> WALK_SHELF ... ->
## WALK_REGISTER -> QUEUE -> CHECKOUT -> EXIT. Runs once per fixed step, customers in ascending
## id order, so the same seeds and ticks always give the same walks and purchases. One customer
## is served per register at a time; the others wait in queue slots 1..2 and advance. A customer who
## has waited QUEUE_TIMEOUT_SEC since reaching the line leaves and every reservation is released. A
## full queue makes the customer wait (WAIT_QUEUE) until a slot frees.
## Baskets (issue #128): a customer with basket_size N chooses N categories in SELECT, runs the buy
## decision for each (skipped when not bought), then visits the shelves nearest-first and reserves one
## unit per item. A stocked-out item is skipped. Checkout takes checkout_base + per_item * items seconds
## and commits all reserved items under one basket transaction id.
## RNG use: `purchases` only — per basket item one draw to pick the category and one for the buy decision
## (for basket_size 1 that is exactly the single-item model; a single draw when there is no candidate).

const WALK_TILES_PER_STEP_FALLBACK := 0.6
const RESERVATION_HOLD_SEC := 600
const MAX_RESELECT := 2
const QUEUE_TIMEOUT_SEC := 120
## The third customer in line (slot 2) makes the queue "long" for the notice.
const LONG_QUEUE_SLOT := 2
const LOW_STOCK_RATIO := 0.25
const TRAIL_MAX := 32   # presentation feed: recent tiles kept per customer (see _record_step)

var _paths := PathService.new()
## Layout-derived caches (blocked set, register plan, fixture access, routed paths). They depend only on the
## grid instance and its revision, which every structural change bumps, so they survive across fixed steps
## and are dropped by _sync_layout() when the layout changes.
var _blocked_cache: Dictionary = {}
var _plan_cache: Dictionary = {}
var _cache_fresh := false
var _path_cache: Dictionary = {}   # Vector4i(start, goal) -> Array[Vector2i] (empty when unreachable)
var _layout_grid: StoreGrid = null
var _layout_rev := -1
var _by_id: Dictionary = {}
var _taken: Dictionary = {}        # register id -> {queue slot: true}; rebuilt when a slot changes
var _taken_dirty := true
var _res_ids: Dictionary = {}      # reservation ids that exist; rebuilt when one is made / released / sold
var _res_dirty := true
var _access_cache: Dictionary = {}   # fixture id -> reachable access tiles (layout-derived)
var _held: Dictionary = {}           # tile -> id of the customer standing still on it (line/till), rebuilt each step
const MAX_ROOM_RADIUS := 3


func _sync_layout(state: GameState) -> void:
	if state.grid != _layout_grid or state.grid.revision != _layout_rev:
		_layout_grid = state.grid
		_layout_rev = state.grid.revision
		_cache_fresh = false
		_access_cache.clear()
		_path_cache.clear()


func _blocked(state: GameState) -> Dictionary:
	_sync_layout(state)
	if not _cache_fresh:
		_blocked_cache = state.grid.blocked_cells()
		_plan_cache = _build_register_plan(state)
		_cache_fresh = true
	return _blocked_cache


## Shortest path on the current layout, memoised per (start, goal). Returns a copy the caller may consume.
func _path(state: GameState, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var blocked := _blocked(state)
	var key := Vector4i(start.x, start.y, goal.x, goal.y)
	if not _path_cache.has(key):
		_path_cache[key] = PathService.find_path(state.grid, blocked, start, goal)
	var cached: Array[Vector2i] = _path_cache[key]
	return cached.duplicate()


func step(state: GameState) -> void:
	_sync_layout(state)
	_spawn(state)
	_taken_dirty = true
	_res_dirty = true
	_held.clear()
	for c in state.customers:
		if _is_standing_in_line(c) and not _held.has(c["tile"]):   # the first one on a tile keeps it
			_held[c["tile"]] = c["customer_id"]
	_by_id.clear()
	var ids: Array[String] = []
	for c in state.customers:
		ids.append(c["customer_id"])
		_by_id[c["customer_id"]] = c
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
			"progress": 0.0, "fixture_id": "", "sku_id": "", "reservation_ids": [], "queue_slot": -1, "retries": 0, "queue_since": 0, "checkout_left": 0, "register_id": "",
			"outcome": "", "basket_size": clampi(int(arrival.get("basket_size", 1)), BasketModel.MIN_SIZE, BasketModel.MAX_SIZE), "wishes": [],
		})
		state.emit_event("CUSTOMER_ENTERED", {"customer_id": arrival["customer_id"]})
	state.arrival_queue.clear()


func _find(state: GameState, id: String) -> Dictionary:
	if _by_id.has(id):
		return _by_id[id]
	for c in state.customers:   # outside step() (tests)
		if c["customer_id"] == id:
			return c
	return {}


func _update(state: GameState, c: Dictionary) -> void:
	match c["phase"]:
		"SELECT":
			_select(state, c)
		"WALK_SHELF":
			if _reservation_lost(state, c):   # an earlier item of the basket timed out on the way
				_leave(state, c, "reservation_lost")
			elif _walk(state, c):
				_pick(state, c)
		"WALK_REGISTER":
			if _reservation_lost(state, c):
				_leave(state, c, "reservation_lost")
			elif _timed_out(state, c):
				_leave(state, c, "queue_timeout")
			elif _walk(state, c):
				c["phase"] = "QUEUE"
		"WAIT_QUEUE":
			if not (c["path"] as Array).is_empty():
				if _walk(state, c):
					_wait_for_slot(state, c)   # arrived at its spot: try the line again
			else:
				_wait_for_slot(state, c)
		"QUEUE":
			_queue(state, c)
		"CHECKOUT":
			_checkout(state, c)
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
		_record_step(c)
	if path.is_empty():
		c["progress"] = 0.0
		return true
	return false


## Presentation feed only (never read by the simulation): the last TRAIL_MAX tiles the customer entered and
## how many steps in total. The shown position in the store follows these tiles, so several steps in one
## frame are walked tile by tile instead of as one straight line (see FixturePresenter).
func _record_step(c: Dictionary) -> void:
	var trail: Array = c.get("trail", [])
	trail.append(c["tile"])
	if trail.size() > TRAIL_MAX:
		trail.pop_front()
	c["trail"] = trail
	c["moved"] = int(c.get("moved", 0)) + 1


func _route(state: GameState, c: Dictionary, goal: Vector2i) -> bool:
	var found := _path(state, c["tile"], goal)
	if found.is_empty():
		return false
	found.pop_front()   # already standing on the first tile
	c["path"] = found
	c["progress"] = 0.0
	return true


## True when one of the customer's reservations no longer exists (expired, released or sold).
func _reservation_lost(state: GameState, c: Dictionary) -> bool:
	if (c["reservation_ids"] as Array).is_empty():
		return false
	if _res_dirty:
		_res_ids.clear()
		for r in state.reservations:
			_res_ids[r["reservation_id"]] = true
		_res_dirty = false
	for id in c["reservation_ids"]:
		if not _res_ids.has(id):
			return true
	return false


## Leaves the store: every reservation goes back to its shelf, stock stays untouched.
func _leave(state: GameState, c: Dictionary, outcome: String) -> void:
	if not (c["reservation_ids"] as Array).is_empty():
		for id in c["reservation_ids"]:
			InventoryService.release_reservation(state, id)
		c["reservation_ids"] = []
		_res_dirty = true
	c["queue_slot"] = -1
	_taken_dirty = true
	c["outcome"] = outcome
	state.emit_event("CUSTOMER_EXITED_NO_PURCHASE", {"customer_id": c["customer_id"], "outcome": outcome})
	if outcome == "queue_timeout":
		state.rate_stats["abandoned"] += 1
	elif outcome == "no_candidate" or outcome == "stockout":
		state.rate_stats["stockouts"] += 1
	_start_exit(state, c)


func _start_exit(state: GameState, c: Dictionary) -> void:
	var reach := _paths.current_distances(state.grid)
	var goal := Vector2i(-1, -1)
	var best := 1 << 30
	for e in state.grid.entrance_tiles:
		var path := _path(state, c["tile"], e)
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
	var plan := _plan_basket(state, c)
	if plan["no_candidate"]:
		_leave(state, c, "no_candidate")
		return
	var wishes: Array = plan["wishes"]
	if wishes.is_empty():
		_leave(state, c, "declined")
		return
	c["wishes"] = wishes
	if not _next_wish(state, c):
		_leave(state, c, "unreachable")


## Chooses the basket (issue #128): for each of basket_size items one category pick (weighted over the
## candidates, categories already in the basket excluded) and one buy decision, in that order. The buy
## decision of an item that is not bought is final for this visit. With basket_size 1 these are exactly the
## two draws of the single-item model. Returns {"wishes": [{sku_id, fixture_id}], "no_candidate": bool}.
func _plan_basket(state: GameState, c: Dictionary) -> Dictionary:
	var rng := Lcg32.new(int(state.rng_states["purchases"]))
	var wishes: Array = []
	var taken := {}
	var size := clampi(int(c.get("basket_size", 1)), BasketModel.MIN_SIZE, BasketModel.MAX_SIZE)
	for k in size:
		var cands := candidates(state).filter(func(x): return x["weight"] > 0.0 and not taken.has(state.products.get_sku(x["sku_id"])["category"]))   # preference 0 = never picked
		if cands.is_empty():
			if k == 0:
				rng.next_state()   # a draw is consumed even without candidates (09 §3)
				state.rng_states["purchases"] = rng.state
				return {"wishes": [], "no_candidate": true}
			break
		var total := 0.0
		for x in cands:
			total += x["weight"]
		var pick := rng.uniform_0_1() * total
		var chosen: Dictionary = cands[cands.size() - 1]
		var acc := 0.0
		for x in cands:
			acc += x["weight"]
			if pick < acc:
				chosen = x
				break
		var buy_p := DemandModel.purchase_probability(_price_factor(state, chosen["sku_id"]), state.balance)
		var buys := rng.uniform_0_1() < buy_p
		taken[state.products.get_sku(chosen["sku_id"])["category"]] = true
		if buys:
			wishes.append({"sku_id": chosen["sku_id"], "fixture_id": chosen["fixture_id"]})
	state.rng_states["purchases"] = rng.state
	return {"wishes": wishes, "no_candidate": false}


## Heads for the nearest wish that can be reached (nearest-first, measured from where the customer stands).
## Unreachable wishes are dropped. Returns false when no wish is left to walk to.
func _next_wish(state: GameState, c: Dictionary) -> bool:
	var wishes: Array = c["wishes"]
	while not wishes.is_empty():
		var best := -1
		var best_len := 1 << 30
		var best_goal := Vector2i(-1, -1)
		for i in wishes.size():
			var access := _shelf_access(state, wishes[i]["fixture_id"])
			if access.is_empty():
				continue
			var path := _path(state, c["tile"], access[0])
			if not path.is_empty() and path.size() < best_len:
				best_len = path.size()
				best = i
				best_goal = access[0]
		if best < 0:
			wishes.clear()
			return false
		var w: Dictionary = wishes[best]
		wishes.remove_at(best)
		c["fixture_id"] = w["fixture_id"]
		c["sku_id"] = w["sku_id"]
		if _route(state, c, best_goal):
			c["phase"] = "WALK_SHELF"
			return true
	return false


## Reachable access tiles of a placed fixture (layout-derived, cached until the layout changes); [] if gone.
func _shelf_access(state: GameState, fixture_id: String) -> Array:
	if not state.grid.instances.has(fixture_id):
		return []
	_sync_layout(state)
	if not _access_cache.has(fixture_id):
		var inst: Dictionary = state.grid.instances[fixture_id]
		var def := state.fixtures.get_type(inst["type_id"])
		_access_cache[fixture_id] = AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], _paths.current_distances(state.grid))
	return _access_cache[fixture_id]


func _price_factor(state: GameState, sku_id: String) -> float:
	return DemandModel.price_factor(int(state.products.get_sku(sku_id)["default_sell_price_yen"]), state.sell_price(sku_id), state.balance)


## (sku_id, fixture_id) pairs a customer could buy right now, sorted by sku then fixture id,
## with weight = availability * accessibility * preference * appeal * demand_weight * price_factor.
func candidates(state: GameState) -> Array[Dictionary]:
	_sync_layout(state)
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
		if not _access_cache.has(loc["fixture_id"]):
			_access_cache[loc["fixture_id"]] = AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach)
		var access: Array = _access_cache[loc["fixture_id"]]
		if access.is_empty():
			continue
		seen["%s|%s" % [seg["sku_id"], loc["fixture_id"]]] = {"sku_id": seg["sku_id"], "fixture_id": loc["fixture_id"]}
	var fx := EventService.effects(state)   # the active event's category weights, applied once here
	var keys := seen.keys()
	keys.sort()
	var out: Array[Dictionary] = []
	for k in keys:
		var e: Dictionary = seen[k]
		var sku := state.products.get_sku(e["sku_id"])
		e["weight"] = DemandModel.category_preference(sku["category"], state.balance) * float(sku["demand_weight"]) * _price_factor(state, e["sku_id"]) * GameplayEventDirector.category_multiplier(fx, sku["category"])
		out.append(e)
	return out


# ---------------------------------------------------------------- PICK / register

## Reserves the unit of the current wish. The first item of an attempt keeps the id res_<customer>_<retries>;
## later items of the same basket add their index. A failed item is skipped (see _on_pick_failed).
func _pick(state: GameState, c: Dictionary) -> void:
	var held: Array = c["reservation_ids"]
	var res_id := "res_%s_%d" % [c["customer_id"], c["retries"]] if held.is_empty() else "res_%s_%d_%d" % [c["customer_id"], c["retries"], held.size()]
	var res := InventoryService.reserve(state, res_id, c["customer_id"], c["sku_id"], RESERVATION_HOLD_SEC, c["fixture_id"])
	if res.is_empty():
		_on_pick_failed(state, c)
		return
	held.append(res["reservation_id"])
	_res_dirty = true
	var sku := state.products.get_sku(c["sku_id"])
	state.emit_event("CUSTOMER_RESERVED_ITEM", {"customer_id": c["customer_id"], "reservation_id": res["reservation_id"], "fixture_id": c["fixture_id"], "sku_id": c["sku_id"], "category": sku.get("category", ""), "name": sku.get("display_name", "")})
	if not (c["wishes"] as Array).is_empty() and _next_wish(state, c):
		return   # the rest of the basket first
	_go_to_register(state, c)


## An item that is out of stock is skipped. When nothing at all was reserved and no item is left, the
## customer reselects (up to MAX_RESELECT times, as in the single-item model) and then leaves.
func _on_pick_failed(state: GameState, c: Dictionary) -> void:
	if not (c["wishes"] as Array).is_empty() and _next_wish(state, c):
		return
	if not (c["reservation_ids"] as Array).is_empty():
		_go_to_register(state, c)
		return
	c["retries"] = int(c["retries"]) + 1
	if int(c["retries"]) > MAX_RESELECT:
		_leave(state, c, "stockout")
	else:
		c["phase"] = "SELECT"


## Every item is reserved (or skipped): the customer joins the line of the first register that has a plan.
func _go_to_register(state: GameState, c: Dictionary) -> void:
	var plan := _register_plan(state)
	if plan.is_empty():
		_leave(state, c, "no_register")
		return
	c["queue_since"] = state.time_sec   # the patience clock starts when the customer reaches the line
	c["register_id"] = plan["register_id"]
	c["phase"] = "WAIT_QUEUE"
	_wait_for_slot(state, c)


func _timed_out(state: GameState, c: Dictionary) -> bool:
	return state.time_sec - int(c["queue_since"]) >= QUEUE_TIMEOUT_SEC


## Takes the front-most free queue slot of the customer's register, or keeps waiting.
func _wait_for_slot(state: GameState, c: Dictionary) -> void:
	if _reservation_lost(state, c):
		_leave(state, c, "reservation_lost")
		return
	var plan := _register_plan(state)
	if plan.is_empty():
		_leave(state, c, "no_register")
		return
	var slot := _free_slot(state, c, plan)
	if slot < 0:
		if _timed_out(state, c):
			_leave(state, c, "queue_timeout")
			return
		_make_room(state, c, plan)
		return
	c["queue_slot"] = slot
	_taken_dirty = true
	if slot >= LONG_QUEUE_SLOT:
		state.emit_event("QUEUE_TOO_LONG", {"register_id": plan["register_id"]})
	if not _route(state, c, plan["queue_cells"][slot]):
		_leave(state, c, "unreachable_register")
		return
	c["phase"] = "WALK_REGISTER"


## A customer who has no slot waits on a tile nobody else stands on: when its own tile is held, it walks to
## the nearest free tile (fixed search order, radius up to MAX_ROOM_RADIUS) and holds that one. Queue cells are
## never used for waiting, so a full line never stacks two people on one tile (issue #16 / #30).
func _make_room(state: GameState, c: Dictionary, plan: Dictionary) -> void:
	var tile: Vector2i = c["tile"]
	var me: String = c["customer_id"]
	if _held.get(tile, me) == me:
		_held[tile] = me
		return
	var queue_cells: Array = plan["queue_cells"]
	var blocked := _blocked(state)
	var reach := _paths.current_distances(state.grid)
	for r in range(1, MAX_ROOM_RADIUS + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cand := tile + Vector2i(dx, dy)
				if not reach.has(cand) or blocked.has(cand) or _held.has(cand) or queue_cells.has(cand) or state.grid.entrance_tiles.has(cand):
					continue
				if _route(state, c, cand):
					_held[cand] = me
					return
	# No free tile nearby: the customer keeps its place (the line stays a presentation question only then).


static func _is_standing_in_line(c: Dictionary) -> bool:
	return (c.get("path", []) as Array).is_empty() and c["phase"] in ["WAIT_QUEUE", "QUEUE", "CHECKOUT"]   # hand-made test customers may have no path


func _free_slot(state: GameState, c: Dictionary, plan: Dictionary) -> int:
	for i in plan["queue_cells"].size():
		if not _slot_taken(state, plan["register_id"], i, c["customer_id"]):
			return i
	return -1


## Is queue slot `slot` of that register held by someone other than `except_id`?
func _slot_taken(state: GameState, register_id: String, slot: int, except_id: String) -> bool:
	if _taken_dirty:
		_taken.clear()
		for other in state.customers:
			if int(other["queue_slot"]) >= 0:
				if not _taken.has(other["register_id"]):
					_taken[other["register_id"]] = {}
				_taken[other["register_id"]][int(other["queue_slot"])] = other["customer_id"]
		_taken_dirty = false
	var holder = _taken.get(register_id, {}).get(slot)
	return holder != null and holder != except_id


## Waiting in the line: start checkout at the service cell when the register is free, otherwise
## step forward into a freed slot, otherwise give up after the timeout.
func _queue(state: GameState, c: Dictionary) -> void:
	if _reservation_lost(state, c):
		_leave(state, c, "reservation_lost")
		return
	var plan := _register_plan(state)
	if plan.is_empty():
		_leave(state, c, "no_register")
		return
	if int(c["queue_slot"]) == 0:
		var busy := false
		for other in state.customers:
			if other["phase"] == "CHECKOUT" and other["register_id"] == c["register_id"]:
				busy = true
		if not busy:
			c["phase"] = "CHECKOUT"
			c["checkout_left"] = BasketModel.checkout_seconds(state.balance, (c["reservation_ids"] as Array).size())
			return
	elif int(c["queue_slot"]) > 0:
		var ahead: int = int(c["queue_slot"]) - 1
		if not _slot_taken(state, c["register_id"], ahead, c["customer_id"]):
			c["queue_slot"] = ahead
			_taken_dirty = true
			if _route(state, c, plan["queue_cells"][ahead]):
				c["phase"] = "WALK_REGISTER"
				return
	if _timed_out(state, c):
		_leave(state, c, "queue_timeout")


func _checkout(state: GameState, c: Dictionary) -> void:
	if _reservation_lost(state, c):
		_leave(state, c, "reservation_lost")
		return
	c["checkout_left"] = int(c["checkout_left"]) - int(GameClock.STEP_GAME_SECONDS)
	if int(c["checkout_left"]) > 0:
		return
	var ids: Array = c["reservation_ids"].duplicate()
	if ids.is_empty():
		_leave(state, c, "sale_failed")
		return
	# One basket transaction: every item is its own ledger row (event id = its sale id), all sharing the
	# first item's sale id as basket id (issue #128). The first row's event id is therefore the basket id.
	var basket_id := "sale:%s" % ids[0]
	c["queue_slot"] = -1
	c["reservation_ids"] = []
	_taken_dirty = true
	_res_dirty = true
	var sold := 0
	var revenue := 0
	var first_sku := ""
	var first_fixture := ""
	for res_id in ids:
		var sku_id := _reservation_sku(state, res_id)
		var sale := InventoryService.complete_sale(state, "sale:%s" % res_id, res_id, basket_id)
		if not sale["ok"]:
			InventoryService.release_reservation(state, res_id)
			continue
		sold += 1
		revenue += int(sale["revenue_yen"])
		if first_sku == "":
			first_sku = sku_id
			first_fixture = sale["fixture_id"]
		if InventoryService.fixture_fill_ratio(state, sale["fixture_id"]) < LOW_STOCK_RATIO:
			state.emit_event("STOCK_LOW", {"fixture_id": sale["fixture_id"]})
	if sold == 0:
		_leave(state, c, "sale_failed")
		return
	state.visit_stats["purchased"] += 1   # a buying customer, however many items (issue #128)
	c["outcome"] = "purchased"
	var name := String(state.products.get_sku(first_sku).get("display_name", ""))
	if sold > 1:
		name = "%s 他%d点" % [name, sold - 1]   # the checkout pop: "おにぎり 他2点 ¥480"
	state.emit_event("SALE_COMMITTED", {"transaction_id": basket_id, "customer_id": c["customer_id"], "revenue_yen": revenue, "register_id": c["register_id"], "fixture_id": first_fixture, "sku_id": first_sku, "name": name, "items": sold})
	_start_exit(state, c)


## SKU of a live reservation (read before the sale removes it); "" when unknown.
func _reservation_sku(state: GameState, reservation_id: String) -> String:
	for r in state.reservations:
		if r["reservation_id"] == reservation_id:
			for seg in state.inventory_segments:
				if seg["segment_id"] == r["segment_id"]:
					return String(seg["sku_id"])
	return ""


## First register (by instance id) that can form a queue: {service_cell, queue_cells} or {}.
func _register_plan(state: GameState) -> Dictionary:
	_blocked(state)
	return _plan_cache


func _build_register_plan(state: GameState) -> Dictionary:
	var reach := _paths.current_distances(state.grid)
	var blocked: Dictionary = _blocked_cache
	var ids := state.grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = state.grid.instances[id]
		var def := state.fixtures.get_type(inst["type_id"])
		if not AccessService.is_register(def) or not inst.get("enabled", true):
			continue
		var plan := AccessService.register_plan(state.grid, def, inst["x"], inst["y"], inst["rotation"], blocked, reach)
		if int(plan["slots"]) > 0:
			plan["register_id"] = id
			return plan
	return {}
