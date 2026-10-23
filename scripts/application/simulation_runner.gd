class_name SimulationRunner
extends RefCounted
## Drives fixed simulation steps from real frame deltas (09 §1).
## SETUP never advances the clock. No sales/cash logic lives in any _process.

var _state: GameState
var _clock := GameClock.new()


func _init(state: GameState) -> void:
	_state = state


## Returns the number of fixed steps executed this frame.
func process_frame(delta: float) -> int:
	if _state.business_state == GameState.SETUP or _state.business_state == GameState.PAYMENT_BLOCKED:
		return 0
	var steps := _clock.advance(delta, _state.speed_setting)
	_state.time_sec += steps * int(GameClock.STEP_GAME_SECONDS)
	return steps
