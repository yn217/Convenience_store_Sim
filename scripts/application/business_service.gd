class_name BusinessService
extends RefCounted
## Business lifecycle rules (08 §1, 03 §5, 12 §4): opening conditions, the once-per-day charges
## (advertising, fixed cost, electricity), the day boundary and closing back to SETUP.
## Every charge is identified by "<day>:<kind>" in the ledger, so it can never be booked twice
## for the same day, whatever the speed, re-open or reload.

const KINDS := ["AD", "DAILY_FIXED", "ELECTRICITY"]


static func charge_event_id(day: int, kind: String) -> String:
	return "%d:%s" % [day, kind]


static func day_charged(state: GameState, day: int) -> bool:
	for kind in KINDS:
		if state.ledger.has_event(charge_event_id(day, kind)):
			return true
	return false


## What `day` costs. The advertising tier is the budget set for it (next_day_ad_yen at the time
## the day is first charged); fixed cost and electricity come from the balance and fixtures.
static func day_costs(state: GameState) -> Dictionary:
	var electricity := 0
	for inst in state.grid.instances.values():
		if inst.get("enabled", true):
			electricity += int(state.fixtures.get_type(inst["type_id"]).get("electricity_cost_yen_per_day", 0))
	return {
		"AD": state.next_day_ad_yen,
		"DAILY_FIXED": int(state.balance.get("daily_fixed_cost_yen", 0)),
		"ELECTRICITY": electricity,
	}


static func total(costs: Dictionary) -> int:
	return int(costs["AD"]) + int(costs["DAILY_FIXED"]) + int(costs["ELECTRICITY"])


## Opening requirements (08 §1): a register with a queue, a stocked shelf customers can reach.
## Returns "" when satisfied, otherwise the failure code.
static func opening_problem(state: GameState) -> StringName:
	var paths := PathService.new()
	var reach := paths.current_distances(state.grid)
	var blocked := state.grid.blocked_cells()
	var has_register := false
	for inst in state.grid.instances.values():
		var def := state.fixtures.get_type(inst["type_id"])
		if AccessService.is_register(def) and inst.get("enabled", true):
			if int(AccessService.register_plan(state.grid, def, inst["x"], inst["y"], inst["rotation"], blocked, reach)["slots"]) > 0:
				has_register = true
	if not has_register:
		return &"MISSING_REGISTER"
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] != "FIXTURE" or int(seg["physical_qty"]) < 1 or not state.grid.instances.has(loc["fixture_id"]):
			continue
		var inst: Dictionary = state.grid.instances[loc["fixture_id"]]
		var def := state.fixtures.get_type(inst["type_id"])
		if inst.get("enabled", true) and not AccessService.reachable_access(state.grid, def, inst["x"], inst["y"], inst["rotation"], reach).is_empty():
			return &""
	return &"MISSING_STOCK"


## Books the day's three charges. `partial` = false pays in full or not at all (opening);
## true pays what cash allows and keeps the rest as unpaid cost (new day while open).
## Returns the yen left unpaid. Events already booked for the day are skipped.
static func charge_day(state: GameState, day: int, partial: bool) -> int:
	var costs := day_costs(state)
	var unpaid := 0
	for kind in KINDS:
		var id := charge_event_id(day, kind)
		var amount: int = costs[kind]
		if state.ledger.has_event(id):
			continue
		var pay := mini(amount, state.cash_yen) if partial else amount
		state.ledger.record(kind, id, -pay, day, state.time_sec, {"cost_yen": amount}, {"expense": amount})
		unpaid += amount - pay
		if kind == "AD":
			state.applied_ad_tier_yen = amount   # today's multiplier follows the tier actually charged
	state.unpaid_cost_yen += unpaid
	return unpaid


## CLOSING ends when the last customer has gone and no reservation is left (08 §1).
static func finish_closing_if_empty(state: GameState) -> bool:
	if state.business_state == GameState.CLOSING and state.customers.is_empty() and state.reservations.is_empty() and state.arrival_queue.is_empty():
		state.business_state = GameState.SETUP
		state.speed_setting = 0
		return true
	return false
