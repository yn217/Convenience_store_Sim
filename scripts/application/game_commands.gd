class_name GameCommands
extends RefCounted
## CommandBus entry point (08 §1.1, §2). Runs in the command phase, so it works
## while the game clock is stopped (speed 0). Only SET_SPEED exists in M0-01;
## other kinds return INVALID_OPERATION until their Issues land.

var _state: GameState


func _init(state: GameState) -> void:
	_state = state


func execute(command: Dictionary) -> CommandResult:
	var command_id := String(command.get("command_id", ""))
	var kind := StringName(command.get("kind", &""))
	if command_id.is_empty() or kind == &"":
		return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"command_malformed")
	if _state.applied_command_ids.has(command_id):
		return CommandResult.failure(&"ALREADY_APPLIED", _state.revision)
	match kind:
		&"SET_SPEED":
			return _set_speed(command_id, command)
		_:
			return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"command_not_implemented")


func _set_speed(command_id: String, command: Dictionary) -> CommandResult:
	var speed = command.get("speed")
	if typeof(speed) != TYPE_INT or not GameState.SPEED_OPTIONS.has(speed):
		return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"speed_invalid")
	if _state.business_state == GameState.SETUP and speed != 0:
		return CommandResult.failure(&"INVALID_OPERATION", _state.revision, &"speed_requires_business")
	_state.speed_setting = speed
	if speed != 0:
		_state.last_nonzero_speed = speed
	_state.revision += 1
	_state.applied_command_ids.append(command_id)
	var events: Array[String] = ["%s:SPEED_CHANGED" % command_id]
	return CommandResult.success(_state.revision, events)
