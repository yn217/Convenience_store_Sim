class_name Company
extends RefCounted
## Several stores of one company (issue #146; user decisions 2026-10-27: one shared purse, stores off screen run on
## an hourly calculation, staff can be transferred, the opening cost depends on the size). The store on screen is
## the running GameState; the others are its `branches` (full GameStates sharing its Ledger, each with its own
## store id / ledger scope), advanced by BranchSim. Opening a store picks a free site on an area map and a size;
## the store starts empty (fixtures are bought separately) with the balance's starting staff, in SETUP.
## Switching makes another store the one on screen: the customers in the store left behind go home (their
## reservations are released) and it carries on under the hourly calculation.

const STORE_PREFIX := "s"


static func stores(active: GameState) -> Array:
	return [active] + active.branches


static func find(active: GameState, store_id: String) -> GameState:
	for s in stores(active):
		if s.store_id == store_id:
			return s
	return null


## "map_id|plot_id" of every store's site.
static func used_sites(active: GameState) -> Dictionary:
	var out := {}
	for s in stores(active):
		if s.plot_id != "":
			out["%s|%s" % [s.map_id, s.plot_id]] = s.store_id
	for r in active.rivals:   # a rival's site is taken too (#129), until it closes
		if not r.has("closed_day"):
			out["%s|%s" % [r["map_id"], r["plot_id"]]] = r["rival_id"]
	return out


## The opening cost of a store of this size (balance store_sizes open_cost_yen).
static func open_cost(balance: Dictionary, size_id: String) -> int:
	return int(StoreSize.find(balance, size_id).get("open_cost_yen", 0))


## Opens a new store on a free map site. -> {"store": GameState} or {"error": key}.
static func open_store(active: GameState, command_id: String, map_id: String, plot_id: String, size_id: String) -> Dictionary:
	var site := WorldMap.site(map_id, plot_id)
	if site.is_empty():
		return {"error": "site_unavailable"}
	if used_sites(active).has("%s|%s" % [map_id, plot_id]):
		return {"error": "site_taken"}
	var size := StoreSize.find(active.balance, size_id)
	if size.is_empty():
		return {"error": "unknown_store_size"}
	var cost := int(size.get("open_cost_yen", 0))
	if cost > active.cash_yen:
		return {"error": "not_enough_cash"}
	var n := stores(active).size() + 1
	var id := "%s%d" % [STORE_PREFIX, n]
	var seeds := {}
	for k in active.rng_states:
		seeds[k] = (int(active.rng_states[k]) + 7919 * n) % 4294967296   # its own random streams
	var s := GameState.from_balance(active.balance, seeds, active.fixtures, active.products)
	s.ledger = active.ledger   # one purse for the company
	s.set_store_id(id)
	var res := StoreSize.resized(s.grid, int(size["width"]), int(size["height"]), s.fixtures)
	s.apply_resized(res)
	s.staff.clear()
	s.next_staff_seq = 0
	if StaffAI.enabled(s.balance):
		for entry in s.balance.get("starting_staff", []):
			s.staff.append(StaffAI.make(s, entry, s.grid.entrance_tiles[0]))
		StaffMarket.draw_candidates(s)
	s.map_id = map_id
	s.plot_id = plot_id
	s.location_id = site["location_id"]
	s.facilities = (site["facilities"] as Array).duplicate()
	s.store_name = String(WorldMap.plot(map_id, plot_id).get("name", id))
	s.day = active.day
	s.time_sec = active.time_sec
	s.milestones = active.milestones
	s.gameplay_events = active.gameplay_events
	s.progression_state = active.progression_state   # one record of achievements for the company
	s.rivals = active.rivals   # the company's rivals (#129)
	s.market_conditions = active.market_conditions
	s.rivals_enabled = active.rivals_enabled
	s.progression_totals = active.progression_totals
	if cost > 0 and not s.ledger.record("FIXTURE_PURCHASE", "store_open:%s" % id, -cost, active.day, active.time_sec, {"store_open": size_id, "command_id": command_id}):
		active.set_store_id(active.store_id)
		return {"error": "not_enough_cash"}
	active.set_store_id(active.store_id)   # the ledger books for the store on screen again
	active.branches.append(s)
	return {"store": s}


## Makes `store_id` the store on screen. -> the new running state, or null when there is no such other store.
static func switch_to(active: GameState, store_id: String) -> GameState:
	var target := find(active, store_id)
	if target == null or target == active:
		return null
	# The store left behind: its customers go home, nothing stays reserved, staff drop their errands.
	for c in active.customers:
		for res_id in c.get("reservation_ids", []):
			InventoryService.release_reservation(active, res_id)
	active.customers.clear()
	active.arrival_queue.clear()
	active.reservations = active.reservations.filter(func(r): return r["customer_id"] == "")
	for st in active.staff:
		st["phase"] = "IDLE"
		st["path"] = [] as Array[Vector2i]
		st["progress"] = 0.0
		st["task"] = {}
		st["carry"] = 0
	var others: Array = active.branches.filter(func(b): return b != target)
	others.append(active)
	active.branches = []
	target.branches = others
	target.time_sec = active.time_sec
	target.day = active.day
	target.speed_setting = active.speed_setting if target.business_state == GameState.OPEN else 0
	target.set_store_id(target.store_id)
	target.revision = active.revision + 1
	target.milestones = active.milestones
	target.gameplay_events = active.gameplay_events
	target.progression_state = active.progression_state
	target.rivals = active.rivals
	target.market_conditions = active.market_conditions
	target.rivals_enabled = active.rivals_enabled
	target.progression_totals = active.progression_totals
	return target


## Moves a staff member between stores while both are closed (SETUP), within the receiving store's cap.
## -> "" or an error key.
static func transfer_staff(active: GameState, staff_id: String, to_store_id: String) -> String:
	var dest := find(active, to_store_id)
	if dest == null:
		return "unknown_store"
	var src: GameState = null
	var person := {}
	for s in stores(active):
		for st in s.staff:
			if st["staff_id"] == staff_id:
				src = s
				person = st
	if src == null:
		return "unknown_staff"
	if src == dest:
		return "same_store"
	if src.business_state != GameState.SETUP or dest.business_state != GameState.SETUP:
		return "stores_must_be_closed"
	if dest.staff.size() >= StaffAI.capacity(dest):
		return "staff_cap_reached"
	src.staff.erase(person)
	person["tile"] = dest.grid.entrance_tiles[0]
	person["phase"] = "IDLE"
	person["path"] = [] as Array[Vector2i]
	person["progress"] = 0.0
	person["task"] = {}
	person["carry"] = 0
	dest.staff.append(person)
	return ""


## The company's figures for `day`: every store's summary of that day (on its own ledger scope) added up, and the
## number of stores. {} for a one-store company.
static func totals(active: GameState, day: int) -> Dictionary:
	if active.branches.is_empty() or day < 0:
		return {}
	var scope := active.ledger.scope
	var out := {"day_index": day, "stores": 0}
	for s in stores(active):
		s.ledger.scope = "" if s.store_id == "" else s.store_id + "/"
		var sum := LedgerSummary.summarize(s.ledger, day)
		for k in ["revenue_yen", "cogs_yen", "gross_profit_yen", "operating_profit_yen", "advertising_yen", "wages_yen", "fixed_cost_yen", "electricity_yen", "wastage_yen", "units_sold"]:
			out[k] = int(out.get(k, 0)) + int(sum.get(k, 0))
		out["stores"] = int(out["stores"]) + 1
	active.ledger.scope = scope
	out["cash_yen"] = active.cash_yen
	return out


## For the 店舗 card: every store with its place, size, state, staff and today's money.
static func views(active: GameState) -> Array:
	var out: Array = []
	var scope := active.ledger.scope
	for s in stores(active):
		s.ledger.scope = "" if s.store_id == "" else s.store_id + "/"
		var today := LedgerSummary.summarize(s.ledger, active.day)
		out.append({"store_id": s.store_id, "name": s.store_name if s.store_name != "" else "1号店", "map_id": s.map_id, "plot_id": s.plot_id,
			"location": StoreLocation.display_name(s.location_id), "size_id": String(StoreSize.of_grid(s.balance, s.grid).get("size_id", "")),
			"business_state": String(s.business_state), "staff": s.staff.map(func(x): return {"staff_id": x["staff_id"], "name": x["name"]}),
			"staff_cap": StaffAI.capacity(s) if StaffAI.enabled(s.balance) else 0,
			"revenue_today": int(today["revenue_yen"]), "profit_today": int(today["operating_profit_yen"]), "active": s == active})
	active.ledger.scope = scope
	return out
