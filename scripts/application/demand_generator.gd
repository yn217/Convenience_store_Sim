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
	var p := DemandModel.step_probability(
		DemandModel.hour_of_day(state.time_sec),
		float(state.balance.get("base_potential_visitors_per_day", 100)),
		DemandModel.ad_multiplier(state.balance.get("advertising_tiers", []), state.applied_ad_tier_yen),
		state.reputation,
		stocked_category_count(state))
	if roll >= p:
		return false
	state.visit_stats["potential"] += 1
	if state.active_customer_count() >= int(state.balance.get("max_active_customers", 30)):
		state.visit_stats["lost"] += 1
		return true
	state.visit_stats["entered"] += 1
	state.next_customer_seq += 1
	state.arrival_queue.append({"customer_id": "cust_%05d" % state.next_customer_seq, "arrived_at_sec": state.time_sec})
	return true


## Distinct categories with stock (qty > 0) on a placed fixture, 0..8. Reachability of the
## fixture's access side is applied by the customer AI, which sets accessibility to 0/1 itself.
static func stocked_category_count(state: GameState) -> int:
	var seen := {}
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and int(seg["physical_qty"]) > 0 and state.grid.instances.has(loc["fixture_id"]):
			seen[state.products.get_sku(seg["sku_id"])["category"]] = true
	return seen.size()
