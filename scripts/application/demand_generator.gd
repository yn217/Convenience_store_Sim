class_name DemandGenerator
extends RefCounted
## One potential-visitor draw per OPEN step (09 §2). It consumes exactly one `arrivals` RNG
## value per step, even when p is 0 or 1, and never touches the other streams. Counters keep
## potential / entered / lost apart; entering customers are queued for the customer AI (M3-02).


## Runs the arrival draw for the step that ended at `state.time_sec`. Returns true when a
## potential visitor was drawn. Does nothing unless the store is OPEN (no draw, no RNG use).
static func step(state: GameState) -> bool:
	if state.business_state != GameState.OPEN:
		return false
	var rng := Lcg32.new(int(state.rng_states["arrivals"]))
	var roll := rng.uniform_0_1()
	state.rng_states["arrivals"] = rng.state
	var hour := DemandModel.hour_of_day(state.time_sec)
	var base := float(state.balance.get("base_potential_visitors_per_day", 100))
	var ad := DemandModel.ad_multiplier(state.balance.get("advertising_tiers", []), state.applied_ad_tier_yen)
	var traffic := float(EventService.effects(state)["traffic"])
	# The probability is monotone in the stocked-category count (0..CATEGORY_COUNT, clamped), so the
	# extremes bound it: a roll at or above the upper bound is no visitor and the shelf scan is skipped.
	var p_max := maxf(
		DemandModel.step_probability(hour, base, ad, state.reputation, 0, state.balance, traffic),
		DemandModel.step_probability(hour, base, ad, state.reputation, DemandModel.CATEGORY_COUNT, state.balance, traffic))
	if roll >= p_max:
		return false
	var p := DemandModel.step_probability(hour, base, ad, state.reputation, stocked_category_count(state), state.balance, traffic)
	if roll >= p:
		return false
	state.visit_stats["potential"] += 1
	if state.active_customer_count() >= int(state.balance.get("max_active_customers", 30)):
		state.visit_stats["lost"] += 1
		return true
	state.visit_stats["entered"] += 1
	state.next_customer_seq += 1
	var arrival := {"customer_id": "cust_%05d" % state.next_customer_seq, "arrived_at_sec": state.time_sec}
	var pick_rng := Lcg32.new(int(state.rng_states["arrivals"]))
	if VisitPurpose.enabled(state.balance):
		# The purpose replaces the basket draw (issue #141): the same one `arrivals` draw picks it; budget and
		# wallet come from the `visits` stream (two draws).
		var money_rng := Lcg32.new(int(state.rng_states["visits"]))
		var v := VisitPurpose.draw(pick_rng, money_rng, hour, state.balance)
		state.rng_states["visits"] = money_rng.state
		arrival.merge({"purpose_id": v["purpose_id"], "budget_yen": v["budget_yen"], "wallet_yen": v["wallet_yen"], "basket_size": v["slots"]})
	else:
		# Basket size is decided at arrival (issue #128): one more `arrivals` draw, only for a visitor who comes in.
		arrival["basket_size"] = BasketModel.draw_size(pick_rng, state.balance)
	state.rng_states["arrivals"] = pick_rng.state
	state.arrival_queue.append(arrival)
	return true


## Distinct categories with stock (qty > 0) on a placed fixture, 0..8. Reachability of the
## fixture's access side is applied by the customer AI, which sets accessibility to 0/1 itself.
static func stocked_category_count(state: GameState) -> int:
	return stocked_categories(state).size()


## Category ids with stock on a placed fixture, sorted.
static func stocked_categories(state: GameState) -> Array:
	var seen := {}
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and int(seg["physical_qty"]) > 0 and state.grid.instances.has(loc["fixture_id"]):
			seen[state.products.get_sku(seg["sku_id"])["category"]] = true
	var out := seen.keys()
	out.sort()
	return out
