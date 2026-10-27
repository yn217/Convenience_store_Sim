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
## Fallbacks for a balance without the keys below (old tests); the balance file sets them for the slow
## #117 v2 pace (a visit lasts 20-30 game minutes, so the old 600 s hold and 120 s patience ran out mid-visit).
const RESERVATION_HOLD_SEC := 600
const MAX_RESELECT := 2
const QUEUE_TIMEOUT_SEC := 120
## The third customer in line (slot 2) makes the queue "long" for the notice.
const LONG_QUEUE_SLOT := 2
## #142: customers come along the pavement. They appear OUTSIDE_MARGIN tiles past the end of the entrance wall, walk
## its pavement row (two tiles out) to the door, and leave the same way. Balance `outdoor_approach` turns it on.
const OUTSIDE_MARGIN := 4
## Within this many tiles (Manhattan) of the line's last cell a customer joins the line at once; farther away it
## walks there first (#117 v2).
const JOIN_RADIUS := 3
const LOW_STOCK_RATIO := 0.25
const TRAIL_MAX := 32   # presentation feed: recent tiles kept per customer (see _record_step)

var _paths := PathService.new()
## Layout-derived caches (blocked set, register plan, fixture access, routed paths). They depend only on the
## grid instance and its revision, which every structural change bumps, so they survive across fixed steps
## and are dropped by _sync_layout() when the layout changes.
var _blocked_cache: Dictionary = {}
var _plan_cache: Dictionary = {}       # the primary register's plan (the first of _plans_cache)
var _plans_cache: Array = []           # every usable register's plan, in instance-id order (#multi-register)
var _all_queue_cells: Dictionary = {}  # every register's queue cells (nobody waits on them)
var _open_cache: Dictionary = {}       # register id -> true when a cashier stands at it or walks to it (per step)
var _open_fresh := false
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
var _owners: Dictionary = {}         # access tile -> [fixture ids it serves] (layout-derived, for impulse checks)
var _owners_fresh := false
var _all_categories: Array = []
var _step_cands: Array = []          # candidates(state) for this step (impulse checks), computed on demand
var _step_cands_fresh := false
var _held: Dictionary = {}           # tile -> id of the customer standing still on it (line/till), rebuilt each step
const MAX_ROOM_RADIUS := 6   # #117 v2: overflow waits gather at the end of the line, so the search reaches further


func _sync_layout(state: GameState) -> void:
	if state.grid != _layout_grid or state.grid.revision != _layout_rev:
		_layout_grid = state.grid
		_layout_rev = state.grid.revision
		_cache_fresh = false
		_access_cache.clear()
		_path_cache.clear()
		_owners_fresh = false


func _blocked(state: GameState) -> Dictionary:
	_sync_layout(state)
	if not _cache_fresh:
		_blocked_cache = state.grid.blocked_cells()
		_plans_cache = _build_register_plans(state)
		_plan_cache = _plans_cache[0] if not _plans_cache.is_empty() else {}
		_all_queue_cells.clear()
		for plan in _plans_cache:
			for cell in plan["queue_cells"]:
				_all_queue_cells[cell] = true
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
	_step_cands_fresh = false
	_open_fresh = false
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
		var seq := int(String(arrival["customer_id"]).right(5).to_int())
		var tile: Vector2i = entrances[seq % entrances.size()]
		var approach: Array[Vector2i] = []
		if outdoor(state.balance):
			approach = outside_route(state.grid, tile, seq % 2 == 0)
		state.customers.append({
			"customer_id": arrival["customer_id"], "phase": "SELECT", "tile": tile, "path": [] as Array[Vector2i],
			"progress": 0.0, "fixture_id": "", "sku_id": "", "reservation_ids": [], "queue_slot": -1, "retries": 0, "queue_since": 0, "checkout_left": 0, "register_id": "",
			"outcome": "", "basket_size": clampi(int(arrival.get("basket_size", 1)), BasketModel.MIN_SIZE, BasketModel.MAX_SIZE), "wishes": [],
			# #141: why the customer came, its budget for the visit and the cash it carries; the basket log
			# (planned / taken / declined / impulse items) and the categories already considered.
			"purpose_id": String(arrival.get("purpose_id", "")), "budget_yen": int(arrival.get("budget_yen", 0)),
			"wallet_yen": int(arrival.get("wallet_yen", 0)), "planned_yen": 0, "impulse_count": 0, "basket_log": [],
			"seen_categories": [], "impulse_tried": [],
			"segment_id": String(arrival.get("segment_id", "")),   # #149: sent by a nearby facility
			"coupon_id": String(arrival.get("coupon_id", "")),     # #137: came back with a coupon
		})
		if approach.is_empty():
			state.emit_event("CUSTOMER_ENTERED", {"customer_id": arrival["customer_id"]})
		else:
			var c: Dictionary = state.customers.back()
			c["tile"] = approach[0]
			approach.pop_front()
			c["path"] = approach
			c["phase"] = "APPROACH"
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
			elif _walk(state, c) and _browsed(state, c):
				_pick(state, c)
		"WALK_REGISTER":
			if _reservation_lost(state, c):
				_leave(state, c, "reservation_lost")
			elif int(c["queue_slot"]) < 0:   # still walking to the line, no slot yet (#117 v2)
				if _walk(state, c):
					_join_line(state, c)
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
				if outdoor(state.balance):
					_walk_away(state, c, seq_of(c) % 2 != 0)   # out of the door and on along the pavement
				else:
					c["phase"] = "GONE"
		"APPROACH":
			if _walk(state, c):
				_at_the_door(state, c)
		"ENTER":
			if _walk(state, c):
				c["phase"] = "SELECT"
				state.emit_event("CUSTOMER_ENTERED", {"customer_id": c["customer_id"]})
		"WALK_AWAY":
			if _walk(state, c):
				c["phase"] = "GONE"
		"WALK_SEAT":   # #134: to a free eat-in seat
			if _walk(state, c):
				c["phase"] = "EAT"
		"EAT":
			c["eat_left"] = int(c.get("eat_left", 0)) - int(GameClock.STEP_GAME_SECONDS)
			if int(c["eat_left"]) <= 0:
				c.erase("seat")
				_start_exit(state, c)


## Moves along the path by this step's walking budget. True once the path is finished.
func _walk(state: GameState, c: Dictionary) -> bool:
	var path: Array = c["path"]
	var speed: float = float(state.balance.get("customer_walk_tiles_per_game_second", WALK_TILES_PER_STEP_FALLBACK))
	c["progress"] = float(c["progress"]) + speed * GameClock.STEP_GAME_SECONDS
	while float(c["progress"]) >= 1.0 and not path.is_empty():
		c["progress"] = float(c["progress"]) - 1.0
		c["tile"] = path.pop_front()
		_record_step(c)
		if c["phase"] == "WALK_SHELF" and not path.is_empty() and _try_impulse(state, c):
			path.clear()   # stops here: the shelf it walks past is the next stop
	if path.is_empty():
		c["progress"] = 0.0
		return true
	return false


## Game seconds a picked item stays reserved for the customer (until it is paid or released).
static func reservation_hold_sec(balance: Dictionary) -> int:
	return int(balance.get("reservation_hold_game_seconds", RESERVATION_HOLD_SEC))


## Game seconds a customer waits for the register (from joining the line) before giving up.
static func queue_timeout_sec(balance: Dictionary) -> int:
	return int(balance.get("queue_patience_game_seconds", QUEUE_TIMEOUT_SEC))


## Impulse pick-up (#141): a customer on its way to a shelf who steps onto the access tile of another shelf may
## take something from it. Each shelf is tried once per visit: the most attractive item there of a category not
## yet considered, if it fits the cash left (wallet minus everything planned), with one `impulse` draw against
## VisitPurpose.impulse_probability. On success the item it was heading for goes back to the front of the wishes
## and the customer stops here to browse this shelf. True when it stops.
func _try_impulse(state: GameState, c: Dictionary) -> bool:
	var purpose := String(c.get("purpose_id", ""))
	if purpose == "" or int(c["impulse_count"]) >= VisitPurpose.max_impulse(state.balance):
		return false
	var owners: Array = _access_owners(state).get(c["tile"], [])
	if owners.is_empty():
		return false
	var tried: Array = c["impulse_tried"]
	var seen: Array = c["seen_categories"]
	var best := {}
	for x in _candidates_this_step(state):
		if not owners.has(x["fixture_id"]) or tried.has(x["fixture_id"]) or x["weight"] <= 0.0:
			continue
		if x["fixture_id"] == c["fixture_id"] or seen.has(state.products.get_sku(x["sku_id"])["category"]):
			continue
		if best.is_empty() or x["weight"] > best["weight"]:
			best = x
	if best.is_empty():
		return false
	tried.append(best["fixture_id"])
	var price := state.sell_price(best["sku_id"])
	if int(c["planned_yen"]) + price > int(c["wallet_yen"]):
		return false
	var cat: String = state.products.get_sku(best["sku_id"])["category"]
	var pref := DemandModel.category_preference(cat, state.balance) * StoreLocation.category_multiplier(state.location_id, cat)
	var p := VisitPurpose.impulse_probability(state.balance, purpose, pref, _price_factor(state, best["sku_id"])) * StoreLocation.impulse_multiplier(state.location_id)
	var rng := Lcg32.new(int(state.rng_states["impulse"]))
	var hit := rng.uniform_0_1() < p
	state.rng_states["impulse"] = rng.state
	if not hit:
		return false
	(c["wishes"] as Array).insert(0, {"sku_id": c["sku_id"], "fixture_id": c["fixture_id"]})
	c["fixture_id"] = best["fixture_id"]
	c["sku_id"] = best["sku_id"]
	c["impulse_count"] = int(c["impulse_count"]) + 1
	c["planned_yen"] = int(c["planned_yen"]) + price
	seen.append(cat)
	(c["basket_log"] as Array).append({"sku_id": best["sku_id"], "price": price, "kind": "impulse", "state": "planned"})
	var sku := state.products.get_sku(best["sku_id"])
	state.emit_event("CUSTOMER_IMPULSE", {"customer_id": c["customer_id"], "fixture_id": best["fixture_id"], "sku_id": best["sku_id"], "category": cat, "name": sku.get("display_name", "")})
	return true


## Access tile -> fixture ids whose (reachable) access side it is (layout-derived, rebuilt after a layout change).
func _access_owners(state: GameState) -> Dictionary:
	_sync_layout(state)
	if not _owners_fresh:
		_owners.clear()
		var ids := state.grid.instances.keys()
		ids.sort()
		for id in ids:
			for t in _shelf_access(state, id):
				if not _owners.has(t):
					_owners[t] = []
				(_owners[t] as Array).append(id)
		_owners_fresh = true
	return _owners


func _candidates_this_step(state: GameState) -> Array:
	if not _step_cands_fresh:
		_step_cands = candidates(state)
		_step_cands_fresh = true
	return _step_cands


## In front of the shelf the customer looks over the goods for a while before taking one (#117 v2): the first
## arrival sets browse_left from the balance range (fixed per customer and shelf, no random draw), later steps
## count it down. True once the time is over (and the shelf is reset for the next wish).
func _browsed(state: GameState, c: Dictionary) -> bool:
	if int(c.get("browse_left", -1)) < 0:
		c["browse_left"] = browse_seconds(state.balance, String(c["customer_id"]), String(c["fixture_id"])) \
			+ Cooking.prep_seconds(String(state.products.get_sku(String(c.get("sku_id", ""))).get("category", "")))   # #131: made to order
	c["browse_left"] = int(c["browse_left"]) - int(GameClock.STEP_GAME_SECONDS)
	if int(c["browse_left"]) > 0:
		return false
	c["browse_left"] = -1
	return true


## Game seconds a customer spends at a shelf: balance browse_min..browse_max, chosen by a hash of the customer
## and the shelf (deterministic and free of the random streams, so the purchase draws do not move).
static func browse_seconds(balance: Dictionary, customer_id: String, fixture_id: String) -> int:
	var lo := int(balance.get("browse_min_game_seconds", 0))
	var hi := maxi(int(balance.get("browse_max_game_seconds", lo)), lo)
	if hi <= 0:
		return 0
	return lo + absi(("%s|%s" % [customer_id, fixture_id]).hash()) % (hi - lo + 1)


## A customer caught between two tiles (#117 v2: a step takes many frames) finishes that step before it turns,
## so a new route never starts from the tile it already left (the figure would jump back across the gap).
func _finish_step(c: Dictionary) -> void:
	var path: Array = c["path"]
	if float(c.get("progress", 0.0)) > 0.0 and not path.is_empty():
		c["tile"] = path.pop_front()
		_record_step(c)
	c["progress"] = 0.0


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
	_finish_step(c)
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
		StaffMarket.note(state, "abandoned")
	elif outcome == "no_candidate" or outcome == "stockout":
		state.rate_stats["stockouts"] += 1
	_start_exit(state, c)


func _start_exit(state: GameState, c: Dictionary) -> void:
	state.note_mood(CustomerMood.of(c, state.time_sec))   # #141: the day's satisfaction
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


# ---------------------------------------------------------------- outside (#142)

static func outdoor(balance: Dictionary) -> bool:
	return bool(balance.get("outdoor_approach", false))


static func seq_of(c: Dictionary) -> int:
	return int(String(c["customer_id"]).right(5).to_int())


## Outward normal of the wall an entrance tile is on (west, north, east, south, as BackdropLayer.entrance_side).
static func door_normal(grid: StoreGrid, door: Vector2i) -> Vector2i:
	if door.x == 0:
		return Vector2i(-1, 0)
	if door.y == 0:
		return Vector2i(0, -1)
	if door.x == grid.width - 1:
		return Vector2i(1, 0)
	return Vector2i(0, 1)


## Pavement walk to a door: from OUTSIDE_MARGIN tiles past one end of the entrance wall (the low end when
## `from_low`) along the row two tiles out, to the tile just outside the door. First tile = where it appears.
static func outside_route(grid: StoreGrid, door: Vector2i, from_low: bool) -> Array[Vector2i]:
	var n := door_normal(grid, door)
	var along := Vector2i(1, 0) if n.y != 0 else Vector2i(0, 1)
	var edge := grid.width if n.y != 0 else grid.height
	var door_a := door.x if n.y != 0 else door.y
	var start_a := -OUTSIDE_MARGIN if from_low else edge - 1 + OUTSIDE_MARGIN
	var row := door + n * 2
	var out: Array[Vector2i] = []
	var step := 1 if door_a >= start_a else -1
	var a := start_a
	while true:
		out.append(row + along * (a - door_a))
		if a == door_a:
			break
		a += step
	out.append(door + n)
	return out


## From the door out to the pavement row and along it OUTSIDE_MARGIN tiles past the end of the wall (the low end
## when `to_low`). The first tile is the one just outside the door.
static func away_route(grid: StoreGrid, door: Vector2i, to_low: bool) -> Array[Vector2i]:
	var n := door_normal(grid, door)
	var along := Vector2i(1, 0) if n.y != 0 else Vector2i(0, 1)
	var edge := grid.width if n.y != 0 else grid.height
	var door_a := door.x if n.y != 0 else door.y
	var end_a := -OUTSIDE_MARGIN if to_low else edge - 1 + OUTSIDE_MARGIN
	var row := door + n * 2
	var out: Array[Vector2i] = [door + n]
	var step := 1 if end_a >= door_a else -1
	var a := door_a
	while true:
		out.append(row + along * (a - door_a))
		if a == end_a:
			break
		a += step
	return out


## The entrance tile nearest to `t` (the door a customer outside is heading for).
static func nearest_door(grid: StoreGrid, t: Vector2i) -> Vector2i:
	var best := grid.entrance_tiles[0]
	for e in grid.entrance_tiles:
		if absi(e.x - t.x) + absi(e.y - t.y) < absi(best.x - t.x) + absi(best.y - t.y):
			best = e
	return best


## At the door (on the tile just outside it): the customer looks at the line and either steps in or turns back.
func _at_the_door(state: GameState, c: Dictionary) -> void:
	var door := nearest_door(state.grid, c["tile"])
	if should_balk(state):
		state.visit_stats["entered"] = int(state.visit_stats["entered"]) - 1   # it never came in
		state.visit_stats["lost"] = int(state.visit_stats["lost"]) + 1
		state.visit_stats["balked"] = int(state.visit_stats.get("balked", 0)) + 1
		state.rate_stats["balked"] = int(state.rate_stats.get("balked", 0)) + 1
		c["outcome"] = "balked"
		state.emit_event("CUSTOMER_BALKED", {"customer_id": c["customer_id"]})
		StaffMarket.note(state, "balked")
		var back := away_route(state.grid, door, seq_of(c) % 2 == 0)   # back the way it came
		back.pop_front()   # it already stands outside the door
		c["path"] = back
		c["progress"] = 0.0
		c["phase"] = "WALK_AWAY"
		return
	var p: Array[Vector2i] = [door]
	c["path"] = p
	c["progress"] = 0.0
	c["phase"] = "ENTER"


## Leaves the store through the door it stands on and walks on along the pavement.
func _walk_away(state: GameState, c: Dictionary, to_low: bool) -> void:
	var door := nearest_door(state.grid, c["tile"])
	if c["tile"] != door:
		c["phase"] = "GONE"
		return
	c["path"] = away_route(state.grid, door, to_low)
	c["progress"] = 0.0
	c["phase"] = "WALK_AWAY"


## Turn back at the door (#142): no register, or the line inside is too long — at least the line's capacity plus
## balance `balk_extra_in_line` people heading for or standing at the registers, or a wait estimate (average
## checkout x people / registers) over balance `balk_wait_game_seconds`.
func should_balk(state: GameState) -> bool:
	var plan := _register_plan(state)
	if plan.is_empty():
		return true
	if StaffAI.enabled(state.balance) and not state.staff.any(func(s): return s["phase"] in ["TO_REGISTER", "REGISTER"]):
		return true   # #143: no staff at (or on the way to) the register: it is closed
	var line := 0
	for o in state.customers:
		if o["phase"] in ["WAIT_QUEUE", "QUEUE", "CHECKOUT", "WALK_REGISTER"]:
			line += 1
	var registers := 0
	for id in state.grid.instances:
		if String(state.grid.instances[id]["type_id"]).begins_with("register"):
			registers += 1
	registers = maxi(registers, 1)
	var capacity: int = (plan["queue_cells"] as Array).size() * registers
	if line >= capacity + int(state.balance.get("balk_extra_in_line", 2)):
		return true
	var avg := BasketModel.checkout_seconds(state.balance, roundi(BasketModel.mean_size(state.balance)))
	return line * avg / registers > int(state.balance.get("balk_wait_game_seconds", 1 << 30))


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
	if String(c.get("purpose_id", "")) != "":
		return _plan_purpose(state, c)
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


## The basket of a customer with a purpose (#141): one item per target slot of the purpose, from the slot's
## categories (not one already considered), weighted like the #128 basket, then the buy decision (the same two
## `purchases` draws per slot). A bought item that does not fit the rest of the budget is declined ("too
## expensive"). A reselect after a stockout plans again from what is already taken.
func _plan_purpose(state: GameState, c: Dictionary) -> Dictionary:
	var rng := Lcg32.new(int(state.rng_states["purchases"]))
	var log: Array = (c["basket_log"] as Array).filter(func(e): return e["state"] != "planned")
	c["basket_log"] = log
	c["planned_yen"] = _sum_yen(log, ["taken"])
	var seen := {}
	for cat in c["seen_categories"]:
		seen[cat] = true
	var all_cands := candidates(state).filter(func(x): return x["weight"] > 0.0)
	var wishes: Array = []
	var found := false
	var purpose := String(c["purpose_id"])
	# #137: a coupon holder came to use it — in a slot that offers the coupon's categories it takes one of them
	# and buys it (the draws stay the same).
	var coupon_cats: Array = []
	if String(c.get("coupon_id", "")) != "":
		for cp in state.coupons:
			if cp["coupon_id"] == c["coupon_id"]:
				coupon_cats = Promotions.definition(cp["def_id"]).get("categories", [])
	for k in int(c["basket_size"]):
		var cats := VisitPurpose.slot_categories(state.balance, purpose, k, _categories(state))
		var cands: Array = []
		for x in all_cands:
			var xc: String = state.products.get_sku(x["sku_id"])["category"]
			if cats.has(xc) and not seen.has(xc):
				cands.append(x)
		if cands.is_empty():
			continue
		found = true
		var for_coupon: Array = cands.filter(func(x): return coupon_cats.has(state.products.get_sku(x["sku_id"])["category"]))
		var coupon_slot := not for_coupon.is_empty()
		if coupon_slot:
			cands = for_coupon
			coupon_cats = []   # one item for the coupon is enough
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
		var buys := rng.uniform_0_1() < buy_p or coupon_slot
		var cat: String = state.products.get_sku(chosen["sku_id"])["category"]
		seen[cat] = true
		var price := state.sell_price(chosen["sku_id"])
		if not buys:
			log.append({"sku_id": chosen["sku_id"], "price": price, "kind": "target", "state": "not_bought"})
		elif int(c["planned_yen"]) + price > int(c["budget_yen"]):
			log.append({"sku_id": chosen["sku_id"], "price": price, "kind": "target", "state": "too_expensive"})
		else:
			wishes.append({"sku_id": chosen["sku_id"], "fixture_id": chosen["fixture_id"]})
			log.append({"sku_id": chosen["sku_id"], "price": price, "kind": "target", "state": "planned"})
			c["planned_yen"] = int(c["planned_yen"]) + price
	if not found:
		rng.next_state()   # a draw is consumed even without candidates (as in the #128 model)
	state.rng_states["purchases"] = rng.state
	var seen_list: Array = seen.keys()
	seen_list.sort()
	c["seen_categories"] = seen_list
	return {"wishes": wishes, "no_candidate": not found}


## Every product category of the catalog, sorted (the "any" slots of a purpose).
func _categories(state: GameState) -> Array:
	if _all_categories.is_empty():
		var seen := {}
		for sku in state.products.skus.values():
			seen[sku["category"]] = true
		_all_categories = seen.keys()
		_all_categories.sort()
	return _all_categories


static func _sum_yen(log: Array, states: Array) -> int:
	var total := 0
	for e in log:
		if states.has(e["state"]):
			total += int(e["price"])
	return total


## Marks the first basket-log entry of `sku_id` in `from_state` as `to_state` (no-op without a log).
static func _mark(c: Dictionary, sku_id: String, from_state: String, to_state: String) -> void:
	for e in c.get("basket_log", []):
		if e["sku_id"] == sku_id and e["state"] == from_state:
			e["state"] = to_state
			return


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
		e["weight"] = DemandModel.category_preference(sku["category"], state.balance) * StoreLocation.category_multiplier(state.location_id, sku["category"]) * float(sku["demand_weight"]) * _price_factor(state, e["sku_id"]) * _category_pull(state, fx, sku["category"])
		out.append(e)
	return out


# ---------------------------------------------------------------- PICK / register

## Reserves the unit of the current wish. The first item of an attempt keeps the id res_<customer>_<retries>;
## later items of the same basket add their index. A failed item is skipped (see _on_pick_failed).
func _pick(state: GameState, c: Dictionary) -> void:
	var held: Array = c["reservation_ids"]
	var res_id := "res_%s_%d" % [c["customer_id"], c["retries"]] if held.is_empty() else "res_%s_%d_%d" % [c["customer_id"], c["retries"], held.size()]
	var res := InventoryService.reserve(state, res_id, c["customer_id"], c["sku_id"], reservation_hold_sec(state.balance), c["fixture_id"])
	if res.is_empty():
		_on_pick_failed(state, c)
		return
	var sku := state.products.get_sku(c["sku_id"])
	state.emit_event("CUSTOMER_RESERVED_ITEM", {"customer_id": c["customer_id"], "reservation_id": res["reservation_id"], "fixture_id": c["fixture_id"], "sku_id": c["sku_id"], "category": sku.get("category", ""), "name": sku.get("display_name", "")})
	_res_dirty = true
	if CapsuleToys.is_capsule(state, c["sku_id"]):
		_turn_machine(state, c, res["reservation_id"])   # #139: paid at the machine
	else:
		held.append(res["reservation_id"])
		_mark(c, c["sku_id"], "planned", "taken")
		_take_more(state, c)
	if not (c["wishes"] as Array).is_empty() and _next_wish(state, c):
		return   # the rest of the basket first
	if held.is_empty() and bool(c.get("machine_bought", false)):
		_done_at_machine(state, c)
		return
	_go_to_register(state, c)


## A capsule machine (#139): the turn is paid at the machine — its own SALE row — and the prize comes out.
func _turn_machine(state: GameState, c: Dictionary, res_id: String) -> void:
	var sale := InventoryService.complete_sale(state, "sale:%s" % res_id, res_id)   # a basket of its own
	if not sale["ok"]:
		InventoryService.release_reservation(state, res_id)
		_mark(c, c["sku_id"], "planned", "stockout")
		return
	_taken_dirty = true
	_mark(c, c["sku_id"], "planned", "taken")
	c["machine_bought"] = true
	var prize := CapsuleToys.on_turned(state, c["sku_id"], "sale:%s" % res_id, c["customer_id"], c["fixture_id"])
	state.emit_event("CAPSULE_TURNED", {"customer_id": c["customer_id"], "fixture_id": c["fixture_id"], "sku_id": c["sku_id"], "prize": prize["name"], "rare": prize["rare"], "revenue_yen": int(sale["revenue_yen"])})
	if InventoryService.fixture_fill_ratio(state, sale["fixture_id"]) < LOW_STOCK_RATIO:
		state.emit_event("STOCK_LOW", {"fixture_id": sale["fixture_id"]})


## A customer who only turned machines (#139) has paid and leaves without queueing.
func _done_at_machine(state: GameState, c: Dictionary) -> void:
	state.visit_stats["purchased"] += 1
	c["outcome"] = "purchased"
	_start_exit(state, c)


## A multi-buy deal on the item's category (#137 phase 2): the customer may take more of the same item — one
## `impulse` draw per extra unit against the deal's extra_take, while it fits the cash left and max_units, and while
## the shelf has it.
func _take_more(state: GameState, c: Dictionary) -> void:
	if state.promotions.is_empty() or int(c.get("wallet_yen", 0)) <= 0:
		return
	var sku_id: String = c["sku_id"]
	var deal := Promotions.multi_for(state, String(state.products.get_sku(sku_id).get("category", "")))
	if deal.is_empty():
		return
	var have := 1
	while have < int(deal["max_units"]):
		var price := state.sell_price(sku_id)
		if int(c["planned_yen"]) + price > int(c["wallet_yen"]):
			return
		var rng := Lcg32.new(int(state.rng_states["impulse"]))
		var roll := rng.uniform_0_1()
		state.rng_states["impulse"] = rng.state
		if roll >= float(deal["extra_take"]):
			return
		var held: Array = c["reservation_ids"]
		var res := InventoryService.reserve(state, "res_%s_%d_%d" % [c["customer_id"], c["retries"], held.size()], c["customer_id"], sku_id, reservation_hold_sec(state.balance), c["fixture_id"])
		if res.is_empty():
			return
		held.append(res["reservation_id"])
		c["planned_yen"] = int(c["planned_yen"]) + price
		(c["basket_log"] as Array).append({"sku_id": sku_id, "price": price, "kind": "deal", "state": "taken"})
		have += 1


## An item that is out of stock is skipped. When nothing at all was reserved and no item is left, the
## customer reselects (up to MAX_RESELECT times, as in the single-item model) and then leaves.
func _on_pick_failed(state: GameState, c: Dictionary) -> void:
	for e in c.get("basket_log", []):
		if e["sku_id"] == c["sku_id"] and e["state"] == "planned":
			e["state"] = "stockout"
			c["planned_yen"] = int(c["planned_yen"]) - int(e["price"])
			break
	if not (c["wishes"] as Array).is_empty() and _next_wish(state, c):
		return
	if not (c["reservation_ids"] as Array).is_empty():
		_go_to_register(state, c)
		return
	if bool(c.get("machine_bought", false)):   # #139: paid at a machine already
		_done_at_machine(state, c)
		return
	c["retries"] = int(c["retries"]) + 1
	if int(c["retries"]) > MAX_RESELECT:
		_leave(state, c, "stockout")
	else:
		c["phase"] = "SELECT"


## Every item is reserved (or skipped): the customer heads for the open register with the shortest line
## (_choose_register).
func _go_to_register(state: GameState, c: Dictionary) -> void:
	var plan := _choose_register(state, c)
	if plan.is_empty():
		_leave(state, c, "no_register")
		return
	c["register_id"] = plan["register_id"]
	# #117 v2: the walk to the register takes minutes. A customer far from the line walks to its end first and
	# only takes a slot there, so the line forms in the order people arrive (a slot held by someone still at
	# the back of the store would block everyone standing behind it).
	var tail: Vector2i = plan["queue_cells"][plan["queue_cells"].size() - 1]
	var far := absi(tail.x - c["tile"].x) + absi(tail.y - c["tile"].y) > JOIN_RADIUS
	c["queue_slot"] = -1
	if far and _route(state, c, tail):
		c["phase"] = "WALK_REGISTER"
		return
	_join_line(state, c)


## At the line: the patience clock starts and the customer takes the front-most free slot (or waits nearby).
func _join_line(state: GameState, c: Dictionary) -> void:
	c["queue_since"] = state.time_sec   # the patience clock starts when the customer reaches the line
	c["phase"] = "WAIT_QUEUE"
	var plan := _choose_register(state, c)   # the walk took minutes: another till may have opened meanwhile
	if not plan.is_empty():
		c["register_id"] = plan["register_id"]
	_wait_for_slot(state, c)


func _timed_out(state: GameState, c: Dictionary) -> bool:
	# #144: a friendly cashier keeps people in the line longer (service 1..5 -> patience x0.9..1.3).
	var patience := float(queue_timeout_sec(state.balance))
	if StaffAI.enabled(state.balance):
		var cashier := StaffAI.cashier(state, String(c["register_id"]))
		if not cashier.is_empty():
			patience *= 0.8 + 0.1 * float(int(cashier["skills"]["service"]))
	return state.time_sec - int(c["queue_since"]) >= int(patience)


## Takes the front-most free queue slot of the customer's register, or keeps waiting.
func _wait_for_slot(state: GameState, c: Dictionary) -> void:
	if _reservation_lost(state, c):
		_leave(state, c, "reservation_lost")
		return
	var plan := _plan_for(state, String(c["register_id"]))
	if plan.is_empty():
		plan = _choose_register(state, c)   # its register went away (layout change): the best one now
		if plan.is_empty():
			_leave(state, c, "no_register")
			return
		c["register_id"] = plan["register_id"]
	var slot := _free_slot(state, c, plan)
	if slot < 0:
		if _switch_line(state, c, -1):
			return
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
	var queue_cells: Array = plan["queue_cells"]
	# A waiting customer never keeps a queue cell (it arrives on the line's last cell, #117 v2): a slot holder
	# would step onto it.
	_blocked(state)
	if _held.get(tile, me) == me and not queue_cells.has(tile) and not _all_queue_cells.has(tile):
		_held[tile] = me
		return
	var blocked := _blocked(state)
	var reach := _paths.current_distances(state.grid)
	queue_cells = _all_queue_cells.keys()   # nobody waits in any register's line
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
	var plan := _plan_for(state, String(c["register_id"]))
	if plan.is_empty():
		_leave(state, c, "no_register")
		return
	# "Next customer, this way please": a better place at another open till (a closed till, or a slot further
	# forward than this one).
	if (int(c["queue_slot"]) > 0 or not _open_registers(state).has(c["register_id"])) and _switch_line(state, c, int(c["queue_slot"])):
		return
	if int(c["queue_slot"]) == 0:
		var busy := false
		for other in state.customers:
			if other["phase"] == "CHECKOUT" and other["register_id"] == c["register_id"]:
				busy = true
		var open := not StaffAI.cashier(state, c["register_id"]).is_empty()   # #143: nobody at the till = closed
		if not busy and open:
			c["phase"] = "CHECKOUT"
			c["waited_sec"] = state.time_sec - int(c.get("queue_since", state.time_sec))   # #141: for the mood
			c["checkout_left"] = StaffAI.checkout_seconds(state, c["register_id"], (c["reservation_ids"] as Array).size())
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
	var sold_categories: Array = []
	var sold_units: Array = []   # {category, price} per unit, for multi-buy deals
	for res_id in ids:
		var sku_id := _reservation_sku(state, res_id)
		var sale := InventoryService.complete_sale(state, "sale:%s" % res_id, res_id, basket_id)
		if not sale["ok"]:
			InventoryService.release_reservation(state, res_id)
			continue
		sold += 1
		sold_categories.append(state.products.get_sku(sku_id).get("category", ""))
		sold_units.append({"category": sold_categories.back(), "price": int(sale["revenue_yen"])})
		revenue += int(sale["revenue_yen"])
		if first_sku == "":
			first_sku = sku_id
			first_fixture = sale["fixture_id"]
		if InventoryService.fixture_fill_ratio(state, sale["fixture_id"]) < LOW_STOCK_RATIO:
			state.emit_event("STOCK_LOW", {"fixture_id": sale["fixture_id"]})
	if sold == 0:
		_leave(state, c, "sale_failed")
		return
	_bundle_discount(state, c, basket_id, sold_categories)
	_multi_discount(state, c, basket_id, sold_units)
	_coupons_at_till(state, c, basket_id, sold_categories, sold_units)
	if not state.lotteries.is_empty():
		var prizes := Lottery.at_till(state, c)   # #138: a prize draw ticket or two
		if not prizes.is_empty():
			c["kuji"] = prizes
	state.visit_stats["purchased"] += 1   # a buying customer, however many items (issue #128)
	c["outcome"] = "purchased"
	var name := String(state.products.get_sku(first_sku).get("display_name", ""))
	if sold > 1:
		name = "%s 他%d点" % [name, sold - 1]   # the checkout pop: "おにぎり 他2点 ¥480"
	state.emit_event("SALE_COMMITTED", {"transaction_id": basket_id, "customer_id": c["customer_id"], "revenue_yen": revenue, "register_id": c["register_id"], "fixture_id": first_fixture, "sku_id": first_sku, "name": name, "items": sold})
	if not _sit_down(state, c, sold_categories):
		_start_exit(state, c)


## Eat-in (#134): a customer who bought something to eat here may take a free seat of an eat-in counter (EatIn).
## -> true when it is on its way to one.
func _sit_down(state: GameState, c: Dictionary, categories: Array) -> bool:
	var counters := EatIn.counters(state)
	if counters.is_empty() or not EatIn.wants(String(c["customer_id"]), categories):
		return false
	var taken := {}
	for o in state.customers:
		if o.has("seat"):
			taken[o["seat"]] = true
	for id in counters:
		for seat in _shelf_access(state, id):
			if taken.has(seat) or not _route(state, c, seat):
				continue
			c["seat"] = seat
			c["eat_left"] = EatIn.stay_seconds(String(c["customer_id"]))
			c["phase"] = "WALK_SEAT"
			state.eat_in_total += 1
			return true
	return false


## The register plan customers use now (StaffAI staffs that register).
func register_plan_now(state: GameState) -> Dictionary:
	_sync_layout(state)
	_blocked(state)
	return _register_plan(state)


## A running bundle (#137) the basket earns: the customer pays discount_yen less, booked once as a DISCOUNT row
## (a promotion expense; the sales keep their own prices).
func _bundle_discount(state: GameState, c: Dictionary, basket_id: String, categories: Array) -> void:
	if state.promotions.is_empty():
		return
	var b := Promotions.bundle_for(state, categories)
	if b.is_empty():
		return
	if state.ledger.record("DISCOUNT", "%s:BUNDLE" % basket_id, -int(b["yen"]), state.day, state.time_sec, {"promotion_id": b["promotion_id"], "customer_id": c["customer_id"]}, {"expense": int(b["yen"])}):
		Promotions.note_sale(state, b["promotion_id"], 1, int(b["yen"]))


## Coupons at the till (#137 phase 2): a returning holder's coupon is redeemed against the basket (DISCOUNT row),
## and a basket of a running coupon promotion's categories gets a new coupon for the next visit.
func _coupons_at_till(state: GameState, c: Dictionary, basket_id: String, categories: Array, units: Array) -> void:
	var brought := ""
	if String(c.get("coupon_id", "")) != "":
		for cp in state.coupons:
			if cp["coupon_id"] == c["coupon_id"]:
				brought = String(cp["def_id"])
		var yen := Promotions.redeem_coupon(state, c["coupon_id"], units)
		if yen > 0 and state.ledger.record("DISCOUNT", "%s:COUPON" % basket_id, -yen, state.day, state.time_sec, {"coupon_id": c["coupon_id"], "customer_id": c["customer_id"]}, {"expense": yen}):
			c["coupon_used"] = true
		c["coupon_id"] = ""
	if not state.promotions.is_empty():
		Promotions.issue_coupon(state, categories, brought)
		var gifts := Promotions.give_gifts(state, units)   # #140: purchase bonuses
		if not gifts.is_empty():
			c["gifts"] = gifts


## Multi-buy deals the basket earns (#137 phase 2): one DISCOUNT row per deal, like a bundle.
func _multi_discount(state: GameState, c: Dictionary, basket_id: String, units: Array) -> void:
	if state.promotions.is_empty():
		return
	for m in Promotions.multi_discounts(state, units):
		if state.ledger.record("DISCOUNT", "%s:MULTI:%s" % [basket_id, m["promotion_id"]], -int(m["yen"]), state.day, state.time_sec, {"promotion_id": m["promotion_id"], "customer_id": c["customer_id"]}, {"expense": int(m["yen"])}):
			Promotions.note_sale(state, m["promotion_id"], int(m["units"]), int(m["yen"]))


## The day's event pull on a category and, while a campaign works, the advertising pull (#136), capped together.
static func _category_pull(state: GameState, fx: Dictionary, category: String) -> float:
	var ev := GameplayEventDirector.category_multiplier(fx, category)
	if not state.market_conditions.is_empty():
		ev *= Market.condition_category(state.market_conditions, state.day, category)   # #129 local conditions
	if not state.promotions.is_empty():
		ev *= Promotions.category_pull(state, category)   # #140 fairs and gifts
	if state.campaigns.is_empty():
		return ev
	return minf(ev * Marketing.category_multiplier(state, category), float(Marketing.data().get("category_cap", 2.5)))


## SKU of a live reservation (read before the sale removes it); "" when unknown.
func _reservation_sku(state: GameState, reservation_id: String) -> String:
	for r in state.reservations:
		if r["reservation_id"] == reservation_id:
			for seg in state.inventory_segments:
				if seg["segment_id"] == r["segment_id"]:
					return String(seg["sku_id"])
	return ""


## The primary register (the first by instance id that can form a queue): {service_cell, queue_cells, ...} or {}.
func _register_plan(state: GameState) -> Dictionary:
	_blocked(state)
	return _plan_cache


## Every register that can form a queue, in instance-id order: {register_id, service_cell, queue_cells, slots,
## cashier_cell}. A later register's line stops where it would run into an earlier one's (cells already used by
## another line or another cashier), and a register left without a slot, or whose cashier would stand where
## another one does, is not used.
func _build_register_plans(state: GameState) -> Array:
	var reach := _paths.current_distances(state.grid)
	var blocked: Dictionary = _blocked_cache
	var used := {}
	var out: Array = []
	var ids := state.grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = state.grid.instances[id]
		var def := state.fixtures.get_type(inst["type_id"])
		if not AccessService.is_register(def) or not inst.get("enabled", true):
			continue
		var plan := AccessService.register_plan(state.grid, def, inst["x"], inst["y"], inst["rotation"], blocked, reach)
		if int(plan["slots"]) <= 0:
			continue
		var cells: Array = []
		for cell in plan["queue_cells"]:
			if used.has(cell):
				break
			cells.append(cell)
		var cashier := StaffAI.cashier_cell(state, id)
		if cells.is_empty() or (cashier.x >= 0 and used.has(cashier)):
			continue
		plan["queue_cells"] = cells
		plan["slots"] = cells.size()
		plan["register_id"] = id
		plan["cashier_cell"] = cashier
		for cell in cells:
			used[cell] = true
		if cashier.x >= 0:
			used[cashier] = true
		out.append(plan)
	return out


## Every usable register's plan (primary first): StaffAI staffs them.
func register_plans_now(state: GameState) -> Array:
	_sync_layout(state)
	_blocked(state)
	return _plans_cache


func _plan_for(state: GameState, register_id: String) -> Dictionary:
	_blocked(state)
	for plan in _plans_cache:
		if plan["register_id"] == register_id:
			return plan
	return {}


## Registers a cashier stands at, for this step (a till someone is still walking to does not count yet: people
## move over once it opens, _switch_line). Without the staff model every register counts as open.
func _open_registers(state: GameState) -> Dictionary:
	if _open_fresh:
		return _open_cache
	_blocked(state)
	_open_cache = {}
	for plan in _plans_cache:
		if not StaffAI.enabled(state.balance):
			_open_cache[plan["register_id"]] = true
			continue
		for st in state.staff:
			if st["phase"] == "REGISTER" and st["tile"] == plan["cashier_cell"]:
				_open_cache[plan["register_id"]] = true
	_open_fresh = true
	return _open_cache


## People heading for, waiting at or paying at a register (not counting `except_id`).
static func line_load(state: GameState, register_id: String, except_id: String = "") -> int:
	var n := 0
	for o in state.customers:
		if o["register_id"] == register_id and o["customer_id"] != except_id and o["phase"] in ["WALK_REGISTER", "WAIT_QUEUE", "QUEUE", "CHECKOUT"]:
			n += 1
	return n


## The register a customer goes to: among the open ones (a cashier standing there), the shortest line, then
## the nearest; with no open till the primary one (a cashier comes to it). The old store (no staff model) always
## uses the primary register.
func _choose_register(state: GameState, c: Dictionary) -> Dictionary:
	_blocked(state)
	if _plans_cache.is_empty():
		return {}
	if not StaffAI.enabled(state.balance) or _plans_cache.size() == 1:
		return _plan_cache
	var open := _open_registers(state)
	var best := {}
	var best_key := []
	for plan in _plans_cache:
		if not open.has(plan["register_id"]):
			continue
		var tail: Vector2i = plan["queue_cells"][plan["queue_cells"].size() - 1]
		var key := [line_load(state, plan["register_id"], c["customer_id"]), absi(tail.x - c["tile"].x) + absi(tail.y - c["tile"].y)]
		if best.is_empty() or key < best_key:
			best = plan
			best_key = key
	return best if not best.is_empty() else _plan_cache


## Moves a waiting customer to another open till where it would stand further forward (any free slot when its own
## till is closed, otherwise a slot ahead of `my_slot`; -1 = no slot yet). The patience clock keeps running.
func _switch_line(state: GameState, c: Dictionary, my_slot: int) -> bool:
	if not StaffAI.enabled(state.balance) or _plans_cache.size() < 2:
		return false
	var open := _open_registers(state)
	var mine_open := open.has(c["register_id"])
	var best := {}
	var best_slot := -1
	for plan in _plans_cache:
		if plan["register_id"] == c["register_id"] or not open.has(plan["register_id"]):
			continue
		var fs := _free_slot(state, c, plan)
		if fs < 0 or (mine_open and my_slot >= 0 and fs >= my_slot):
			continue
		if best.is_empty() or fs < best_slot:
			best = plan
			best_slot = fs
	if best.is_empty():
		return false
	if not _route(state, c, best["queue_cells"][best_slot]):
		return false
	c["register_id"] = best["register_id"]
	c["queue_slot"] = best_slot
	c["phase"] = "WALK_REGISTER"
	_taken_dirty = true
	return true
