class_name GameCommands
extends RefCounted
## CommandBus entry point (08 §1.1, §2). Runs in the command phase, so it works while the
## game clock is stopped (speed 0). Implemented: SET_SPEED and the layout commands
## PLACE/MOVE/REMOVE_FIXTURE + UNDO/REDO_LAYOUT. Other kinds return INVALID_OPERATION until
## their Issues land. Every command validates first and mutates only when it cannot fail.

const LAYOUT_KINDS: Array[StringName] = [
	&"PLACE_FIXTURE", &"MOVE_FIXTURE", &"REMOVE_FIXTURE", &"UNDO_LAYOUT", &"REDO_LAYOUT",
]

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
		&"UNDO_LAYOUT":
			result = _undo(command_id)
		&"REDO_LAYOUT":
			result = _redo(command_id)
		_:
			return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"command_not_implemented")
	if result.ok and not LAYOUT_KINDS.has(kind):
		_state.layout_history.clear()
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


# ---------------------------------------------------------------- PLACE / MOVE / REMOVE

func _place(command_id: String, command: Dictionary) -> CommandResult:
	if not _require_setup():
		return _fail(&"NOT_IN_SETUP", &"construction_needs_setup")
	var type_id = command.get("type_id")
	if typeof(type_id) != TYPE_STRING or not _is_int(command.get("x")) or not _is_int(command.get("y")) or not _is_int(command.get("rotation")):
		return _fail(&"INVALID_OPERATION", &"command_malformed")
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
