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
	for i in steps:
		_run_step()
	if steps > 0:
		_state.layout_history.clear()   # time passing ends the editing session (04 §8)
	return steps


## One fixed step in the order of 03 §B: expiry sweep first, then new arrivals. The customer AI
## and checkout (M3-02..04) slot in after these.
func _run_step() -> void:
	_state.time_sec += int(GameClock.STEP_GAME_SECONDS)
	InventoryService.sweep_expired(_state)
	DemandGenerator.step(_state)
