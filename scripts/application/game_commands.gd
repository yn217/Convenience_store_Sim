class_name GameCommands
extends RefCounted
## CommandBus entry point (08 §1.1, §2). Runs in the command phase, so it works while the
## game clock is stopped (speed 0). Implemented: SET_SPEED, SET_PRICE, ORDER_STOCK, RESTOCK, SET_NEXT_DAY_AD, START_BUSINESS,
## REQUEST_CLOSE and the layout commands
## PLACE/MOVE/REMOVE_FIXTURE + UNDO/REDO_LAYOUT. Other kinds return INVALID_OPERATION until
## their Issues land. Every command validates first and mutates only when it cannot fail.

const LAYOUT_KINDS: Array[StringName] = [
	&"PLACE_FIXTURE", &"MOVE_FIXTURE", &"REMOVE_FIXTURE", &"UNDO_LAYOUT", &"REDO_LAYOUT", &"MOVE_ENTRANCE",
]

## Sanity ceiling for a typed price; the spec only fixes the lower bound (>= 1).
const MAX_PRICE_YEN := 99999

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## Read-only preview for the UI (08 §1.1): never changes state, cash or reservations.
## Read-only preview of MOVE_ENTRANCE (#121): "" when the entrance can go to the wall tiles starting at (x, y).
func validate_entrance(x: int, y: int) -> String:
	if _state.business_state != GameState.SETUP:
		return "construction_needs_setup"
	return EntranceRules.check(_state.grid, _state.fixtures, EntranceRules.tiles_at(_state.grid.width, _state.grid.height, x, y))


func validate_placement(type_id: String, x: int, y: int, rotation: int, move_instance_id: String = "") -> PlacementResult:
	if _state.business_state != GameState.SETUP:
		var r := PlacementResult.new()
		r.code = &"NOT_IN_SETUP"
		r.message_key = &"construction_needs_setup"
		return r
	return PlacementRules.validate(_state.grid, _state.fixtures, type_id, x, y, rotation, _state.ledger.cash_yen, move_instance_id, move_instance_id.is_empty())


func execute(command: Dictionary) -> CommandResult:
	var command_id := String(command.get("command_id", ""))
	var kind := StringName(command.get("kind", &""))
	if command_id.is_empty() or kind == &"":
		return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"command_malformed")
	if _state.applied_command_ids.has(command_id):
		return CommandResult.failure(&"ALREADY_APPLIED", _state.revision)
	if _state.rank_gating:   # store rank (StoreRank): a fixture or feature opens at its rank
		var need := rank_needed(kind, command)
		if need > int(_state.progression_state.get("store_rank", 1)):
			return _fail(&"INVALID_OPERATION", StringName("rank_locked_%d" % need))
	var result: CommandResult
	match kind:
		&"SET_SPEED":
			result = _set_speed(command_id, command)
		&"PLACE_FIXTURE":
			result = _place(command_id, command)
		&"MOVE_FIXTURE":
			result = _move(command_id, command)
		&"REMOVE_FIXTURE":
			result = _remove(command_id, command)
		&"SET_PRICE":
			result = _set_price(command_id, command)
		&"DISMISS_STORY_CUE":
			result = _dismiss_story_cue(command_id, command)
		&"SET_TUTORIAL_SKIPPED":
			result = _set_tutorial_skipped(command_id, command)
		&"SET_NEXT_DAY_AD":
			result = _set_next_day_ad(command_id, command)
		&"START_BUSINESS":
			result = _start_business(command_id)
		&"REQUEST_CLOSE":
			result = _request_close(command_id)
		&"ORDER_STOCK":
			result = _stock_result(command_id, StockOps.order(_state, command_id, command.get("sku_id"), command.get("qty")))
		&"RESTOCK":
			if not _require_setup():
				return _fail(&"NOT_IN_SETUP", &"restock_needs_setup")
			result = _stock_result(command_id, StockOps.restock(_state, command_id, command.get("instance_id"), command.get("slot_id"), command.get("sku_id"), command.get("qty")))
		&"SET_RIVALS":   # #129: rival stores on or off (the company's)
			var on := bool(command.get("enabled", true))
			if not on and ScenarioService.active(_state) and ScenarioService.needs_rivals(ScenarioService.definition(_state)):
				return _fail(&"INVALID_OPERATION", &"scenario_needs_rivals")
			for st in Company.stores(_state):
				st.rivals_enabled = on
			var rv: Array[String] = ["%s:RIVALS_SET" % command_id]
			result = _commit(command_id, rv)
		&"OPEN_STORE":
			var opened := Company.open_store(_state, command_id, String(command.get("map_id", "")), String(command.get("plot_id", "")), String(command.get("size_id", "")))
			if opened.has("error"):
				result = _fail(&"INSUFFICIENT_CASH" if opened["error"] == "not_enough_cash" else &"INVALID_OPERATION", StringName(opened["error"]))
			else:
				var ev: Array[String] = ["%s:STORE_OPENED" % command_id]
				result = _commit(command_id, ev, {"store_id": (opened["store"] as GameState).store_id})
		&"TRANSFER_STAFF":
			var terr := Company.transfer_staff(_state, String(command.get("staff_id", "")), String(command.get("to_store_id", "")))
			if terr != "":
				result = _fail(&"INVALID_OPERATION", StringName(terr))
			else:
				var tev: Array[String] = ["%s:STAFF_TRANSFERRED" % command_id]
				result = _commit(command_id, tev)
		&"BOOK_CAMPAIGN":
			result = _campaign_result(command_id, Marketing.book(_state, command_id, String(command.get("medium", "")), int(command.get("days", 0)), int(command.get("daily_budget_yen", 0)), String(command.get("category", ""))), "CAMPAIGN_BOOKED")
		&"CANCEL_CAMPAIGN":
			result = _campaign_result(command_id, Marketing.cancel(_state, String(command.get("campaign_id", ""))), "CAMPAIGN_CANCELLED")
		&"START_PROMOTION":
			result = _promotion_result(command_id, Promotions.start(_state, command_id, String(command.get("def_id", "")), int(command.get("days", 0))), "PROMOTION_STARTED")
		&"CHOOSE_EVENT_OPTION":   # an event choice (EventService.choose)
			result = _promotion_result(command_id, EventService.choose(_state, command_id, String(command.get("choice_id", ""))), "EVENT_CHOICE_MADE")
		&"START_LOTTERY":   # #138
			result = _promotion_result(command_id, Lottery.start(_state, command_id, String(command.get("set_id", ""))), "LOTTERY_STARTED")
		&"STOP_PROMOTION":
			result = _promotion_result(command_id, Promotions.stop(_state, String(command.get("promotion_id", ""))), "PROMOTION_STOPPED")
		&"SET_STORE_SIZE":
			result = _set_store_size(command_id, String(command.get("size_id", "")))
		&"EXPAND_STORE":
			result = _expand_store(command_id)
		&"MOVE_ENTRANCE":   # #121
			result = _move_entrance(command_id, command.get("x"), command.get("y"))
		&"SET_SITE":
			result = _set_site(command_id, String(command.get("map_id", WorldMap.DEFAULT_MAP)), String(command.get("plot_id", "")))
		&"SET_FACILITIES":
			result = _set_facilities(command_id, command.get("facility_ids", []))
		&"SET_LOCATION":
			result = _set_location(command_id, String(command.get("location_id", "")))
		&"REPAIR_CRANE":   # #132 phase 2
			result = _repair_crane(command_id, String(command.get("fixture_id", "")))
		&"HIRE_STAFF":
			result = _staff_result(command_id, StaffMarket.hire(_state, String(command.get("candidate_id", ""))), "STAFF_HIRED")
		&"FIRE_STAFF":
			result = _staff_result(command_id, StaffMarket.fire(_state, String(command.get("staff_id", ""))), "STAFF_LEFT")
		&"UNDO_LAYOUT":
			result = _undo(command_id)
		&"REDO_LAYOUT":
			result = _redo(command_id)
		_:
			return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"command_not_implemented")
	if result.ok and not LAYOUT_KINDS.has(kind):
		_state.layout_history.clear()
	if result.ok:
		ProgressionService.evaluate(_state)
	return result


# ---------------------------------------------------------------- shared helpers

func _commit(command_id: String, events: Array[String], data: Dictionary = {}) -> CommandResult:
	_state.revision += 1
	_state.applied_command_ids.append(command_id)
	return CommandResult.success(_state.revision, events, &"", data)


## The store rank a command needs; 1 for everything open from the start.
static func rank_needed(kind: StringName, command: Dictionary) -> int:
	match kind:
		&"PLACE_FIXTURE":
			return StoreRank.rank_for(String(command.get("type_id", "")))
		&"START_PROMOTION":
			return StoreRank.rank_for("promotions")
		&"BOOK_CAMPAIGN":
			return StoreRank.rank_for("media")
		&"EXPAND_STORE":
			return StoreRank.rank_for("expand_store")
		&"START_LOTTERY":
			return StoreRank.rank_for("lottery")
		&"OPEN_STORE":
			return StoreRank.rank_for("open_store")
	return 1


func _fail(code: StringName, message: StringName = &"") -> CommandResult:
	return CommandResult.failure(code, _state.revision, message)


func _require_setup() -> bool:
	return _state.business_state == GameState.SETUP


func _is_int(v) -> bool:
	return typeof(v) == TYPE_INT


func _pose(instance_id: String) -> Dictionary:
	var inst: Dictionary = _state.grid.instances[instance_id]
	return {"x": inst["x"], "y": inst["y"], "rotation": inst["rotation"]}


func _reserved_on(instance_id: String) -> bool:
	for res in _state.reservations:
		for seg in _state.inventory_segments:
			if seg["segment_id"] == res.get("segment_id") and seg["location"].get("fixture_id") == instance_id:
				return true
	return false


# ---------------------------------------------------------------- SET_SPEED

func _set_speed(command_id: String, command: Dictionary) -> CommandResult:
	var speed = command.get("speed")
	if typeof(speed) != TYPE_INT or not GameState.SPEED_OPTIONS.has(speed):
		return _fail(&"INVALID_OPERATION", &"speed_invalid")
	if _state.business_state == GameState.SETUP and speed != 0:
		return _fail(&"INVALID_OPERATION", &"speed_requires_business")
	_state.speed_setting = speed
	if speed != 0:
		_state.last_nonzero_speed = speed
	var events: Array[String] = ["%s:SPEED_CHANGED" % command_id]
	return _commit(command_id, events)


# ---------------------------------------------------------------- assistant cues

## Closes an assistant card for good (saved). Only known cue ids are accepted; closing one twice is a no-op error.
func _dismiss_story_cue(command_id: String, command: Dictionary) -> CommandResult:
	var cue = command.get("cue_id")
	if typeof(cue) != TYPE_STRING or not AssistantService.CUES.has(cue):
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	var dismissed: Array = _state.progression_state["dismissed_story_cue_ids"]
	if dismissed.has(cue):
		return _fail(&"INVALID_OPERATION", &"no_change")
	dismissed.append(cue)
	var events: Array[String] = ["%s:STORY_CUE_DISMISSED" % command_id]
	return _commit(command_id, events)


# ---------------------------------------------------------------- tutorial visibility

## Hide or show the tutorial. Progress itself is judged from state and is never lost by this.
func _set_tutorial_skipped(command_id: String, command: Dictionary) -> CommandResult:
	var skipped = command.get("skipped")
	if typeof(skipped) != TYPE_BOOL:
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	_state.progression_state["tutorial_skipped"] = skipped
	var events: Array[String] = ["%s:TUTORIAL_VISIBILITY_CHANGED" % command_id]
	return _commit(command_id, events)


# ---------------------------------------------------------------- business lifecycle / advertising

## Only the five tiers are valid. Choosing one never moves cash: it is charged (once) when the
## next game day is first charged. A tier the cash could not cover today is refused.
func _set_next_day_ad(command_id: String, command: Dictionary) -> CommandResult:
	var tier = command.get("tier_yen")
	var known := false
	for t in _state.balance.get("advertising_tiers", []):
		if typeof(tier) == TYPE_INT and int(t["yen_per_day"]) == tier:
			known = true
	if not known:
		return _fail(&"INVALID_OPERATION", &"ad_tier_invalid")
	if tier > _state.cash_yen:
		return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
	_state.next_day_ad_yen = tier
	var events: Array[String] = ["%s:AD_BUDGET_SCHEDULED" % command_id]
	return _commit(command_id, events, {"tier_yen": tier})


## SETUP -> OPEN at speed 1. All checks and the day's charges are one atomic commit: any failure
## leaves state, cash and ledger exactly as they were. Charges already booked today are not repeated.
func _start_business(command_id: String) -> CommandResult:
	if _state.business_state != GameState.SETUP:
		return _fail(&"INVALID_OPERATION", &"already_open")
	var problem := BusinessService.opening_problem(_state)
	if problem != &"":
		return _fail(problem, StringName(String(problem).to_lower()))
	var work := _state.construction_days
	if work > 0:   # #145: the days of the expansion work pass first
		if BusinessService.total(BusinessService.day_costs(_state)) * (work + 1) > _state.cash_yen:
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
		_pass_construction_days(work)
	if not BusinessService.day_charged(_state, _state.day):
		if BusinessService.total(BusinessService.day_costs(_state)) > _state.cash_yen:
			if work > 0:   # the work days already passed and were charged: keep them, only the opening waits
				return _commit(command_id, ["%s:CONSTRUCTION_FINISHED" % command_id], {"construction_days": work, "opened": false})
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
		BusinessService.charge_day(_state, _state.day, false)
	_state.business_state = GameState.OPEN
	_state.speed_setting = 1
	_state.last_nonzero_speed = 1
	var events: Array[String] = ["%s:BUSINESS_STARTED" % command_id]
	if work > 0:
		events.push_front("%s:CONSTRUCTION_FINISHED" % command_id)
	return _commit(command_id, events, {"construction_days": work})


## The expansion work (#145): the store stays shut for `days` days before it opens. Each of them is charged like a
## business day (fixed cost, electricity, wages, ads) and reported with no sales; the date moves on hour by hour,
## so stock still expires, the day's events and the rivals move on, and the company's other stores keep trading.
func _pass_construction_days(days: int) -> void:
	for i in days:
		if not BusinessService.day_charged(_state, _state.day):
			BusinessService.charge_day(_state, _state.day, false)
		var midnight := (_state.day + 1) * DemandModel.SECONDS_PER_DAY
		while _state.time_sec < midnight:
			var prev_day := _state.time_sec / DemandModel.SECONDS_PER_DAY
			_state.time_sec = mini((_state.time_sec / 3600 + 1) * 3600, midnight)
			InventoryService.sweep_expired(_state)
			if _state.bakes_pending > 0:
				Cooking.finish_bakes(_state)
			EventService.step(_state)
			var new_day := _state.time_sec / DemandModel.SECONDS_PER_DAY
			if new_day != prev_day:
				SimulationRunner.roll_day(_state, prev_day, new_day)
				Market.on_new_day(_state)
			BranchSim.step(_state)
	_state.construction_days = 0


func _request_close(command_id: String) -> CommandResult:
	if _state.business_state != GameState.OPEN:
		return _fail(&"INVALID_OPERATION", &"not_open")
	_state.business_state = GameState.CLOSING
	if _state.speed_setting == 0:
		_state.speed_setting = _state.last_nonzero_speed
	var events: Array[String] = ["%s:BUSINESS_CLOSING_REQUESTED" % command_id]
	return _commit(command_id, events)


# ---------------------------------------------------------------- ORDER_STOCK / RESTOCK (StockOps)

func _stock_result(command_id: String, r: Dictionary) -> CommandResult:
	if not r["ok"]:
		return _fail(r["code"], r["key"])
	var events: Array[String] = [r["event"]]
	return _commit(command_id, events, r["data"])


# ---------------------------------------------------------------- SET_PRICE

## Allowed in every business state. Only the override map changes: lot costs, open
## reservations and ledger rows keep the price they were snapshotted with (03).
## BOOK_CAMPAIGN / CANCEL_CAMPAIGN (#136): any business state, also while paused.
func _campaign_result(command_id: String, err: String, event: String) -> CommandResult:
	if err != "":
		return _fail(&"INSUFFICIENT_CASH" if err == "not_enough_cash" else &"INVALID_OPERATION", StringName(err))
	var events: Array[String] = ["%s:%s" % [command_id, event]]
	return _commit(command_id, events)


## START_PROMOTION / STOP_PROMOTION (#137): any business state, also while paused.
func _promotion_result(command_id: String, err: String, event: String) -> CommandResult:
	if err != "":
		return _fail(&"INSUFFICIENT_CASH" if err == "not_enough_cash" else &"INVALID_OPERATION", StringName(err))
	var events: Array[String] = ["%s:%s" % [command_id, event]]
	return _commit(command_id, events)


## SET_STORE_SIZE (#145): the size of a new store, before it first opens (no cost). Fixtures keep their place
## relative to the entrance wall; a size they do not fit in is refused.
func _set_store_size(command_id: String, size_id: String) -> CommandResult:
	if _state.location_locked():
		return _fail(&"INVALID_OPERATION", &"store_size_locked")
	var size := StoreSize.find(_state.balance, size_id)
	if size.is_empty():
		return _fail(&"INVALID_OPERATION", &"unknown_store_size")
	return _resize(command_id, size, 0, "STORE_SIZE_SET")


## EXPAND_STORE (#145): one size up while the store is closed (SETUP), for the bigger size's expand_cost_yen.
func _expand_store(command_id: String) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"expansion_needs_setup")
	var size := StoreSize.next(_state.balance, _state.grid)
	if size.is_empty():
		return _fail(&"INVALID_OPERATION", &"largest_store")
	var r := _resize(command_id, size, int(size.get("expand_cost_yen", 0)), "STORE_EXPANDED")
	if r.ok:
		_state.construction_days += int(size.get("construction_days", 0))   # #145: shut that long when it opens
	return r


## MOVE_ENTRANCE (#121): the entrance moves to two tiles on an outer wall starting at (x, y), while closed (準備中),
## for entrance_move_cost_yen (building work, booked like a fixture purchase). Refused when a fixture stands there or
## when a fixture or a register would be cut off (EntranceRules).
func _move_entrance(command_id: String, x, y) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	if typeof(x) != TYPE_INT or typeof(y) != TYPE_INT:
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	var tiles := EntranceRules.tiles_at(_state.grid.width, _state.grid.height, x, y)
	var err := EntranceRules.check(_state.grid, _state.fixtures, tiles)
	if err != "":
		return _fail(&"INVALID_OPERATION", StringName(err))
	var cost := int(_state.balance.get("entrance_move_cost_yen", 0))
	if cost > 0:
		if _state.ledger.cash_yen < cost:
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
		if not _state.ledger.record("FIXTURE_PURCHASE", "%s:ENTRANCE" % command_id, -cost, _state.day, _state.time_sec, {"entrance": [tiles[0].x, tiles[0].y]}):
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
	var from := _state.grid.entrance_tiles.duplicate()
	_set_entrance(tiles)
	_state.layout_history.push({   # #121: undoable like a placement (refunded on undo, paid again on redo)
		"kind": "ENTRANCE", "instance_id": "", "type_id": "", "from": from, "to": tiles.duplicate(),
		"cost_yen": cost, "purchase_event_id": "%s:ENTRANCE" % command_id if cost > 0 else "", "segments": [],
	})
	var events: Array[String] = ["%s:ENTRANCE_MOVED" % command_id]
	return _commit(command_id, events, {"entrance_tiles": tiles})


func _set_entrance(tiles: Array[Vector2i]) -> void:
	_state.grid.entrance_tiles = tiles
	_state.grid.revision += 1   # paths and access are worked out again


func _resize(command_id: String, size: Dictionary, cost: int, event: String) -> CommandResult:
	var res := StoreSize.resized(_state.grid, int(size["width"]), int(size["height"]), _state.fixtures)
	if res.has("error"):
		return _fail(&"INVALID_OPERATION", StringName(res["error"]))
	if cost > 0:
		if _state.ledger.cash_yen < cost:
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
		if not _state.ledger.record("FIXTURE_PURCHASE", "%s:EXPANSION" % command_id, -cost, _state.day, _state.time_sec, {"expansion": size["size_id"]}):
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
	_state.apply_resized(res)
	var events: Array[String] = ["%s:%s" % [command_id, event]]
	return _commit(command_id, events, {"size_id": size["size_id"]})


## SET_SITE (#150): the store's site on the area map, until it first opens. The site sets the location (#148) and
## the nearby facilities (#149) from the map.
func _set_site(command_id: String, map_id: String, plot_id: String) -> CommandResult:
	if _state.location_locked():
		return _fail(&"INVALID_OPERATION", &"site_locked")
	if ScenarioService.site_fixed(_state):
		return _fail(&"INVALID_OPERATION", &"scenario_site_fixed")
	var site := WorldMap.site(map_id, plot_id)
	if site.is_empty():
		return _fail(&"INVALID_OPERATION", &"site_unavailable")
	_state.map_id = map_id
	_state.plot_id = plot_id
	_state.location_id = site["location_id"]
	_state.facilities = (site["facilities"] as Array).duplicate()
	var events: Array[String] = ["%s:SITE_SET" % command_id]
	return _commit(command_id, events)


## SET_FACILITIES (#149): the store's nearby facilities, until it first opens (like the location).
func _set_facilities(command_id: String, ids) -> CommandResult:
	if _state.location_locked():
		return _fail(&"INVALID_OPERATION", &"facilities_locked")
	if ScenarioService.site_fixed(_state):
		return _fail(&"INVALID_OPERATION", &"scenario_site_fixed")
	if typeof(ids) != TYPE_ARRAY or (ids as Array).size() > NearbyFacility.max_count():
		return _fail(&"INVALID_OPERATION", &"too_many_facilities")
	var out: Array = []
	for id in ids:
		if NearbyFacility.find(String(id)).is_empty() or out.has(String(id)):
			return _fail(&"INVALID_OPERATION", &"unknown_facility")
		out.append(String(id))
	_state.facilities = out
	_state.plot_id = ""   # chosen by hand: no longer the map site's surroundings
	var events: Array[String] = ["%s:FACILITIES_SET" % command_id]
	return _commit(command_id, events)


## SET_LOCATION (#148): only before the store first opens; "" = the standard store.
func _set_location(command_id: String, location_id: String) -> CommandResult:
	if _state.location_locked():
		return _fail(&"INVALID_OPERATION", &"location_locked")
	if ScenarioService.site_fixed(_state):
		return _fail(&"INVALID_OPERATION", &"scenario_site_fixed")
	if location_id != "" and StoreLocation.find(location_id).is_empty():
		return _fail(&"INVALID_OPERATION", &"unknown_location")
	_state.location_id = location_id
	_state.plot_id = ""
	var events: Array[String] = ["%s:LOCATION_SET" % command_id]
	return _commit(command_id, events)


## HIRE_STAFF / FIRE_STAFF (#144): allowed in every business state and while paused.
func _repair_crane(command_id: String, fixture_id: String) -> CommandResult:
	var err := CraneGame.repair(_state, fixture_id, command_id)
	if err == "not_enough_cash":
		return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
	if err != "":
		return _fail(&"INVALID_OPERATION", StringName(err))
	var events: Array[String] = ["%s:CRANE_REPAIRED" % command_id]
	return _commit(command_id, events, {"fixture_id": fixture_id})


func _staff_result(command_id: String, err: String, event: String) -> CommandResult:
	if not StaffAI.enabled(_state.balance):
		return _fail(&"INVALID_OPERATION", &"staff_disabled")
	if err != "":
		return _fail(&"INVALID_OPERATION", StringName(err))
	var events: Array[String] = ["%s:%s" % [command_id, event]]
	return _commit(command_id, events)


func _set_price(command_id: String, command: Dictionary) -> CommandResult:
	var sku_id = command.get("sku_id")
	var price = command.get("price_yen")
	if typeof(sku_id) != TYPE_STRING or not _state.products.has_sku(sku_id):
		return _fail(&"INVALID_OPERATION", &"sku_unknown")
	if not _is_int(price) or price < 1 or price > MAX_PRICE_YEN:
		return _fail(&"INVALID_OPERATION", &"price_invalid")
	if price == _state.list_price(sku_id):
		return _fail(&"INVALID_OPERATION", &"no_change")
	if price == int(_state.products.get_sku(sku_id)["default_sell_price_yen"]):
		_state.product_price_overrides.erase(sku_id)
	else:
		_state.product_price_overrides[sku_id] = price
	var events: Array[String] = ["%s:SKU_PRICE_CHANGED" % command_id]
	return _commit(command_id, events, {"sku_id": sku_id, "price_yen": price})


# ---------------------------------------------------------------- PLACE / MOVE / REMOVE

func _place(command_id: String, command: Dictionary) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	var type_id = command.get("type_id")
	if typeof(type_id) != TYPE_STRING or not _is_int(command.get("x")) or not _is_int(command.get("y")) or not _is_int(command.get("rotation")):
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	var room_def := _state.fixtures.get_type(type_id)
	if int(room_def.get("staff_capacity", 0)) > 0:   # #143: one staff room per store, sized to the store
		if StaffAI.staff_room(_state) != "":
			return _fail(&"INVALID_OPERATION", &"staff_room_exists")
		if int(room_def.get("min_store_width", 0)) > _state.grid.width:
			return _fail(&"INVALID_OPERATION", &"store_too_small")
	if CraneGame.is_machine_type(room_def) and CraneGame.machines(_state, type_id) >= int(CraneGame.data().get("max_per_store", 2)):
		return _fail(&"INVALID_OPERATION", &"crane_limit")   # #132 phase 2
	var res := PlacementRules.validate(_state.grid, _state.fixtures, type_id, command["x"], command["y"], command["rotation"], _state.ledger.cash_yen)
	if not res.ok:
		return _fail(res.code, res.message_key)
	var instance_id := "fx_%04d" % (_state.next_fixture_seq + 1)
	var purchase_id := "%s:FIXTURE_PURCHASE" % command_id
	if not _state.ledger.record("FIXTURE_PURCHASE", purchase_id, -res.cost_yen, _state.day, _state.time_sec, {"type_id": type_id, "instance_id": instance_id}):
		return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
	_add_instance(instance_id, type_id, command["x"], command["y"], command["rotation"])
	_state.next_fixture_seq += 1
	_state.layout_history.push({
		"kind": "PLACE", "instance_id": instance_id, "type_id": type_id,
		"from": null, "to": {"x": command["x"], "y": command["y"], "rotation": command["rotation"]},
		"cost_yen": res.cost_yen, "purchase_event_id": purchase_id, "segments": [],
	})
	var events: Array[String] = ["%s:FIXTURE_PLACED" % command_id, purchase_id]
	return _commit(command_id, events, {"instance_id": instance_id})


func _add_instance(instance_id: String, type_id: String, x: int, y: int, rotation: int) -> void:
	_state.grid.add_instance({"instance_id": instance_id, "type_id": type_id, "x": x, "y": y, "rotation": rotation, "enabled": true}, _state.fixtures)


func _move(command_id: String, command: Dictionary) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	var instance_id = command.get("instance_id")
	if typeof(instance_id) != TYPE_STRING or not _is_int(command.get("x")) or not _is_int(command.get("y")) or not _is_int(command.get("rotation")):
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	if not _state.grid.instances.has(instance_id):
		return _fail(&"INVALID_OPERATION", &"unknown_instance")
	if _reserved_on(instance_id):
		return _fail(&"RESERVATION_ACTIVE", &"reservation_active")
	var from := _pose(instance_id)
	var to := {"x": command["x"], "y": command["y"], "rotation": command["rotation"]}
	if from == to:
		return _fail(&"INVALID_OPERATION", &"no_change")
	var type_id: String = _state.grid.instances[instance_id]["type_id"]
	var res := PlacementRules.validate(_state.grid, _state.fixtures, type_id, to["x"], to["y"], to["rotation"], _state.ledger.cash_yen, instance_id, false)
	if not res.ok:
		return _fail(res.code, res.message_key)
	_state.grid.move_instance(instance_id, to["x"], to["y"], to["rotation"], _state.fixtures)
	_state.layout_history.push({
		"kind": "MOVE", "instance_id": instance_id, "type_id": type_id, "from": from, "to": to,
		"cost_yen": 0, "purchase_event_id": "", "segments": [],
	})
	var events: Array[String] = ["%s:FIXTURE_MOVED" % command_id]
	return _commit(command_id, events)


func _remove(command_id: String, command: Dictionary) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	var instance_id = command.get("instance_id")
	if typeof(instance_id) != TYPE_STRING:
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	if not _state.grid.instances.has(instance_id):
		return _fail(&"INVALID_OPERATION", &"unknown_instance")
	if _reserved_on(instance_id):
		return _fail(&"RESERVATION_ACTIVE", &"reservation_active")
	var type_id: String = _state.grid.instances[instance_id]["type_id"]
	var pose := _pose(instance_id)
	var moved := _stock_to_backroom(instance_id)
	_state.grid.remove_instance(instance_id)
	_state.layout_history.push({
		"kind": "REMOVE", "instance_id": instance_id, "type_id": type_id, "from": pose, "to": null,
		"cost_yen": 0, "purchase_event_id": "", "segments": moved,
	})
	var events: Array[String] = ["%s:FIXTURE_REMOVED" % command_id]
	return _commit(command_id, events)


## Moves every stock segment on the fixture to the backroom; returns the old locations.
func _stock_to_backroom(instance_id: String) -> Array:
	var moved: Array = []
	for seg in _state.inventory_segments:
		if seg["location"].get("fixture_id") == instance_id:
			moved.append({"segment_id": seg["segment_id"], "location": seg["location"].duplicate()})
			seg["location"] = {"kind": "BACKROOM"}
	return moved


func _restore_stock(segments: Array) -> void:
	for saved in segments:
		for seg in _state.inventory_segments:
			if seg["segment_id"] == saved["segment_id"]:
				seg["location"] = saved["location"].duplicate()


# ---------------------------------------------------------------- UNDO / REDO

func _undo(command_id: String) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	var history := _state.layout_history
	if not history.can_undo():
		return _fail(&"INVALID_OPERATION", &"nothing_to_undo")
	var e: Dictionary = history.undo_stack.back()
	var events: Array[String] = []
	match e["kind"]:
		"PLACE":
			var reversal_id := "%s:REVERSAL" % command_id
			if not _state.ledger.record("REVERSAL", reversal_id, int(e["cost_yen"]), _state.day, _state.time_sec, {"reverses": e["purchase_event_id"]}):
				return _fail(&"INVALID_OPERATION", &"reversal_rejected")
			_state.grid.remove_instance(e["instance_id"])
			events.append(reversal_id)
		"MOVE":
			var back: Dictionary = e["from"]
			var res := PlacementRules.validate(_state.grid, _state.fixtures, e["type_id"], back["x"], back["y"], back["rotation"], _state.ledger.cash_yen, e["instance_id"], false)
			if not res.ok:
				return _fail(res.code, res.message_key)
			_state.grid.move_instance(e["instance_id"], back["x"], back["y"], back["rotation"], _state.fixtures)
		"REMOVE":
			var pose: Dictionary = e["from"]
			var res2 := PlacementRules.validate(_state.grid, _state.fixtures, e["type_id"], pose["x"], pose["y"], pose["rotation"], _state.ledger.cash_yen, "", false)
			if not res2.ok:
				return _fail(res2.code, res2.message_key)
			_add_instance(e["instance_id"], e["type_id"], pose["x"], pose["y"], pose["rotation"])
			_restore_stock(e["segments"])
		"ENTRANCE":   # #121: the door goes back, the building work is refunded
			var back_tiles: Array[Vector2i] = []
			back_tiles.assign(e["from"])
			var err := EntranceRules.check(_state.grid, _state.fixtures, back_tiles)
			if err != "":
				return _fail(&"INVALID_OPERATION", StringName(err))
			if int(e["cost_yen"]) > 0:
				var refund_id := "%s:REVERSAL" % command_id
				if not _state.ledger.record("REVERSAL", refund_id, int(e["cost_yen"]), _state.day, _state.time_sec, {"reverses": e["purchase_event_id"]}):
					return _fail(&"INVALID_OPERATION", &"reversal_rejected")
				events.append(refund_id)
			_set_entrance(back_tiles)
	history.undo_stack.pop_back()
	history.redo_stack.append(e)
	events.append("%s:LAYOUT_UNDONE" % command_id)
	return _commit(command_id, events)


func _redo(command_id: String) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	var history := _state.layout_history
	if not history.can_redo():
		return _fail(&"INVALID_OPERATION", &"nothing_to_redo")
	var e: Dictionary = history.redo_stack.back()
	var events: Array[String] = []
	match e["kind"]:
		"PLACE":
			var to: Dictionary = e["to"]
			var res := PlacementRules.validate(_state.grid, _state.fixtures, e["type_id"], to["x"], to["y"], to["rotation"], _state.ledger.cash_yen)
			if not res.ok:
				return _fail(res.code, res.message_key)
			var purchase_id := "%s:FIXTURE_PURCHASE" % command_id
			if not _state.ledger.record("FIXTURE_PURCHASE", purchase_id, -res.cost_yen, _state.day, _state.time_sec, {"type_id": e["type_id"], "instance_id": e["instance_id"]}):
				return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
			_add_instance(e["instance_id"], e["type_id"], to["x"], to["y"], to["rotation"])
			e["cost_yen"] = res.cost_yen
			e["purchase_event_id"] = purchase_id
			events.append(purchase_id)
		"MOVE":
			var dest: Dictionary = e["to"]
			var res2 := PlacementRules.validate(_state.grid, _state.fixtures, e["type_id"], dest["x"], dest["y"], dest["rotation"], _state.ledger.cash_yen, e["instance_id"], false)
			if not res2.ok:
				return _fail(res2.code, res2.message_key)
			_state.grid.move_instance(e["instance_id"], dest["x"], dest["y"], dest["rotation"], _state.fixtures)
		"REMOVE":
			if _reserved_on(e["instance_id"]):
				return _fail(&"RESERVATION_ACTIVE", &"reservation_active")
			_stock_to_backroom(e["instance_id"])
			_state.grid.remove_instance(e["instance_id"])
		"ENTRANCE":
			var to_tiles: Array[Vector2i] = []
			to_tiles.assign(e["to"])
			var err2 := EntranceRules.check(_state.grid, _state.fixtures, to_tiles)
			if err2 != "":
				return _fail(&"INVALID_OPERATION", StringName(err2))
			if int(e["cost_yen"]) > 0:
				var pay_id := "%s:ENTRANCE" % command_id
				if not _state.ledger.record("FIXTURE_PURCHASE", pay_id, -int(e["cost_yen"]), _state.day, _state.time_sec, {"entrance": [to_tiles[0].x, to_tiles[0].y]}):
					return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
				e["purchase_event_id"] = pay_id
				events.append(pay_id)
			_set_entrance(to_tiles)
	history.redo_stack.pop_back()
	history.undo_stack.append(e)
	events.append("%s:LAYOUT_REDONE" % command_id)
	return _commit(command_id, events)
