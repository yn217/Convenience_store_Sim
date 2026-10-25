class_name GameCommands
extends RefCounted
## CommandBus entry point (08 §1.1, §2). Runs in the command phase, so it works while the
## game clock is stopped (speed 0). Implemented: SET_SPEED, SET_PRICE, ORDER_STOCK, RESTOCK, SET_NEXT_DAY_AD, START_BUSINESS,
## REQUEST_CLOSE and the layout commands
## PLACE/MOVE/REMOVE_FIXTURE + UNDO/REDO_LAYOUT. Other kinds return INVALID_OPERATION until
## their Issues land. Every command validates first and mutates only when it cannot fail.

const LAYOUT_KINDS: Array[StringName] = [
	&"PLACE_FIXTURE", &"MOVE_FIXTURE", &"REMOVE_FIXTURE", &"UNDO_LAYOUT", &"REDO_LAYOUT",
]

## Sanity ceiling for a typed price; the spec only fixes the lower bound (>= 1).
const MAX_PRICE_YEN := 99999

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


## Read-only preview for the UI (08 §1.1): never changes state, cash or reservations.
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
		&"SET_LOCATION":
			result = _set_location(command_id, String(command.get("location_id", "")))
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
	if not BusinessService.day_charged(_state, _state.day):
		if BusinessService.total(BusinessService.day_costs(_state)) > _state.cash_yen:
			return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
		BusinessService.charge_day(_state, _state.day, false)
	_state.business_state = GameState.OPEN
	_state.speed_setting = 1
	_state.last_nonzero_speed = 1
	var events: Array[String] = ["%s:BUSINESS_STARTED" % command_id]
	return _commit(command_id, events)


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
## SET_LOCATION (#148): only before the store first opens; "" = the standard store.
func _set_location(command_id: String, location_id: String) -> CommandResult:
	if _state.location_locked():
		return _fail(&"INVALID_OPERATION", &"location_locked")
	if location_id != "" and StoreLocation.find(location_id).is_empty():
		return _fail(&"INVALID_OPERATION", &"unknown_location")
	_state.location_id = location_id
	var events: Array[String] = ["%s:LOCATION_SET" % command_id]
	return _commit(command_id, events)


## HIRE_STAFF / FIRE_STAFF (#144): allowed in every business state and while paused.
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
	if price == _state.sell_price(sku_id):
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
	history.redo_stack.pop_back()
	history.undo_stack.append(e)
	events.append("%s:LAYOUT_REDONE" % command_id)
	return _commit(command_id, events)
