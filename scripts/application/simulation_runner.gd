class_name SimulationRunner
extends RefCounted
## Drives fixed simulation steps from real frame deltas (09 §1).
## SETUP never advances the clock. No sales/cash logic lives in any _process.

var _state: GameState
var _clock := GameClock.new()
var _customers := CustomerAI.new()
var _staff := StaffAI.new()


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
		ProgressionService.evaluate(_state)
		_state.layout_history.clear()   # time passing ends the editing session (04 §8)
	return steps


## One fixed step in the order of 03 §B: expiry sweep first, then new arrivals, then customers. The customer AI
## runs after these; checkout and queue timeouts (M3-03/04) slot in next.
func _run_step() -> void:
	var prev_day := _state.time_sec / DemandModel.SECONDS_PER_DAY
	_state.time_sec += int(GameClock.STEP_GAME_SECONDS)
	InventoryService.sweep_expired(_state)
	InventoryService.release_timed_out(_state)
	EventService.step(_state)
	DemandGenerator.step(_state)
	if StaffAI.enabled(_state.balance):
		_staff.step(_state, _customers.register_plans_now(_state))   # every usable register, primary first
	_customers.step(_state)
	if StaffAI.enabled(_state.balance):
		StaffMarket.record_step(_state)
	var new_day := _state.time_sec / DemandModel.SECONDS_PER_DAY
	if new_day != prev_day:
		_state.close_day_once(prev_day)   # report before the new day's costs (12 §4)
		_state.day = new_day
		_state.facility_visits.clear()   # #149: today's visitors per facility
		_state.visitors_by_hour_yesterday = _state.visitors_by_hour   # #150
		_state.visitors_by_hour = []
		for s in _state.staff:
			s["fatigue"] = 0.0   # a new day, a fresh shift (#143)
		if StaffAI.enabled(_state.balance):
			StaffMarket.draw_candidates(_state)   # new faces every morning (#144)
		_charge_new_day()
	BusinessService.finish_closing_if_empty(_state)


## Midnight while OPEN/CLOSING: the new day's costs are recognised once and paid as far as cash
## allows; any remainder becomes unpaid cost and blocks the store (03 §5).
func _charge_new_day() -> void:
	var unpaid := BusinessService.charge_day(_state, _state.day, true)
	if unpaid > 0:
		_state.business_state = GameState.PAYMENT_BLOCKED
		_state.speed_setting = 0
