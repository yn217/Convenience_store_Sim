class_name DemandGenerator
extends RefCounted
## One potential-visitor draw per OPEN step (09 §2). It consumes exactly one `arrivals` RNG
## value per step, even when p is 0 or 1, and never touches the other streams. Counters keep
## potential / entered / lost apart; entering customers are queued for the customer AI (M3-02).


## Runs the arrival draw for the step that ended at `state.time_sec`. Returns true when a
## potential visitor was drawn. Does nothing unless the store is OPEN (no draw, no RNG use).
## Nearby facilities (#149) draw after the location's visitor, one `arrivals` value each, so a store without
## facilities keeps exactly the arrivals it had.
static func step(state: GameState) -> bool:
	if state.business_state != GameState.OPEN:
		return false
	var drawn := _location_step(state)
	if not state.coupons.is_empty() and _coupon_step(state):   # #137: coupon holders coming back
		drawn = true
	for fid in state.facilities:
		if _facility_step(state, NearbyFacility.find(fid)):
			drawn = true
	return drawn


## A visitor sent by a nearby facility (#149): one `arrivals` draw for "does someone come", and for someone who
## does two more (segment, purpose) plus the `visits` money draws. The visitor counts as a potential visitor like
## any other and is refused at max_active_customers.
static func _facility_step(state: GameState, f: Dictionary) -> bool:
	if f.is_empty():
		return false
	var rng := Lcg32.new(int(state.rng_states["arrivals"]))
	var roll := rng.uniform_0_1()
	state.rng_states["arrivals"] = rng.state
	var hour := DemandModel.hour_of_day(state.time_sec)
	if roll >= NearbyFacility.step_probability(f, hour, float(EventService.effects(state)["traffic"])) * Market.visitor_factor(state, state.rivals, state.day):
		return false
	var pick_rng := Lcg32.new(int(state.rng_states["arrivals"]))
	var who := NearbyFacility.draw_visitor(pick_rng, f, state.balance, stocked_categories(state))
	state.rng_states["arrivals"] = pick_rng.state
	if who.is_empty():
		return false   # nothing on the shelves for them
	state.visit_stats["potential"] += 1
	state.count_visitor_hour()   # #150: the actual curve beside the map forecast
	if state.active_customer_count() >= int(state.balance.get("max_active_customers", 30)):
		state.visit_stats["lost"] += 1
		return true
	state.visit_stats["entered"] += 1
	state.facility_visits[f["facility_id"]] = int(state.facility_visits.get(f["facility_id"], 0)) + 1
	state.next_customer_seq += 1
	var money_rng := Lcg32.new(int(state.rng_states["visits"]))
	var v := VisitPurpose.money(money_rng, VisitPurpose.find(state.balance, who["purpose_id"]), state.location_id)
	state.rng_states["visits"] = money_rng.state
	state.arrival_queue.append({"customer_id": "cust_%05d" % state.next_customer_seq, "arrived_at_sec": state.time_sec,
		"purpose_id": v["purpose_id"], "budget_yen": v["budget_yen"], "wallet_yen": v["wallet_yen"], "basket_size": v["slots"],
		"segment_id": who["segment_id"]})
	return true


## A coupon holder coming back (#137 phase 2): one `arrivals` draw for "does someone come"; the visitor comes for
## a purpose that includes the coupon's categories (VisitPurpose.draw_for) and carries the coupon to the till. Counts as a potential visitor.
static func _coupon_step(state: GameState) -> bool:
	var ret := Promotions.coupon_return(state)
	if String(ret["coupon_id"]) == "":
		return false
	var rng := Lcg32.new(int(state.rng_states["arrivals"]))
	var roll := rng.uniform_0_1()
	state.rng_states["arrivals"] = rng.state
	if roll >= float(ret["p"]):
		return false
	state.visit_stats["potential"] += 1
	state.count_visitor_hour()
	if state.active_customer_count() >= int(state.balance.get("max_active_customers", 30)):
		state.visit_stats["lost"] += 1
		return true
	state.visit_stats["entered"] += 1
	for c in state.coupons:
		if c["coupon_id"] == ret["coupon_id"]:
			c["returning"] = true
	state.next_customer_seq += 1
	var arrival := {"customer_id": "cust_%05d" % state.next_customer_seq, "arrived_at_sec": state.time_sec, "coupon_id": ret["coupon_id"]}
	var pick_rng := Lcg32.new(int(state.rng_states["arrivals"]))
	var money_rng := Lcg32.new(int(state.rng_states["visits"]))
	var cats: Array = []
	for c in state.coupons:
		if c["coupon_id"] == ret["coupon_id"]:
			cats = Promotions.definition(c["def_id"]).get("categories", [])
	var v := VisitPurpose.draw_for(pick_rng, money_rng, DemandModel.hour_of_day(state.time_sec), state.balance, state.location_id, stocked_categories(state), cats)   # comes to use it
	state.rng_states["arrivals"] = pick_rng.state
	state.rng_states["visits"] = money_rng.state
	arrival.merge({"purpose_id": v["purpose_id"], "budget_yen": v["budget_yen"], "wallet_yen": v["wallet_yen"], "basket_size": v["slots"]})
	state.arrival_queue.append(arrival)
	return true


## The location's own visitor (09 §2, #148).
static func _location_step(state: GameState) -> bool:
	var rng := Lcg32.new(int(state.rng_states["arrivals"]))
	var roll := rng.uniform_0_1()
	state.rng_states["arrivals"] = rng.state
	var hour := DemandModel.hour_of_day(state.time_sec)
	var base := float(state.balance.get("base_potential_visitors_per_day", 100)) * StoreLocation.visitors_multiplier(state.location_id)
	if not state.rivals.is_empty() or not state.market_conditions.is_empty():
		base *= Market.visitor_factor(state, state.rivals, state.day)   # #129: rivals nearby take a share, local conditions
	if not state.promotions.is_empty():
		base *= Promotions.visitor_factor(state)   # #140: fairs
	if not state.lotteries.is_empty():
		base *= Lottery.visitor_factor(state)   # #138: a draw whose top prize is left
	var curve: Array = [] if state.location_id == "" else StoreLocation.hour_weights(state.location_id)   # #148
	var ad := DemandModel.ad_multiplier(state.balance.get("advertising_tiers", []), state.applied_ad_tier_yen)
	var traffic := float(EventService.effects(state)["traffic"])
	ad = Marketing.ad_factor(state, hour, ad, traffic)   # #136: media campaigns join the tier in one capped pool
	# The probability is monotone in the stocked-category count (0..CATEGORY_COUNT, clamped), so the
	# extremes bound it: a roll at or above the upper bound is no visitor and the shelf scan is skipped.
	var p_max := maxf(
		DemandModel.step_probability(hour, base, ad, state.reputation, 0, state.balance, traffic, curve),
		DemandModel.step_probability(hour, base, ad, state.reputation, DemandModel.CATEGORY_COUNT, state.balance, traffic, curve))
	if roll >= p_max:
		return false
	var p := DemandModel.step_probability(hour, base, ad, state.reputation, stocked_category_count(state), state.balance, traffic, curve)
	if roll >= p:
		return false
	state.visit_stats["potential"] += 1
	state.count_visitor_hour()   # #150: the actual curve beside the map forecast
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
		var v := VisitPurpose.draw(pick_rng, money_rng, hour, state.balance, state.location_id, stocked_categories(state))
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
