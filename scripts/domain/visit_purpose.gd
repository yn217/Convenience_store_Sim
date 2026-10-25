class_name VisitPurpose
extends RefCounted
## Visit purposes (issue #141, docs/design/CUSTOMER_STAFF_V2.md §3): why a customer came. Each purpose in
## balance["visit_purposes"] has target slots (one item each, from the listed categories; "any" = every category),
## a budget range in yen, a wallet factor range (cash on hand = budget x factor), an impulse factor and 24 hour
## weights. Pure functions; the draws come from the caller's streams.
## A balance without visit_purposes, or with basket_size_forced (test override), keeps the #128 basket model.

const ANY := "any"


static func enabled(balance: Dictionary) -> bool:
	return not (balance.get("visit_purposes", []) as Array).is_empty() and int(balance.get("basket_size_forced", 0)) <= 0


static func find(balance: Dictionary, purpose_id: String) -> Dictionary:
	for p in balance.get("visit_purposes", []):
		if p["purpose_id"] == purpose_id:
			return p
	return {}


static func display_name(balance: Dictionary, purpose_id: String) -> String:
	return String(find(balance, purpose_id).get("display_name", ""))


## Purpose for an arrival at `hour`: one draw from `pick_rng` (weighted by the purposes' hour weights; when every
## weight is 0 the first purpose), then the budget and the wallet from `money_rng` (two draws). Budget and wallet
## are rounded to 10 yen. -> {purpose_id, budget_yen, wallet_yen, slots}.
## The store location (#148) scales each purpose's weight and the budget.
## `stocked` (#147): the categories on the shelves; a purpose whose first target the store does not carry (coffee
## without a coffee machine) does not bring anyone. Empty = no filter.
static func draw(pick_rng: Lcg32, money_rng: Lcg32, hour: int, balance: Dictionary, location_id: String = "", stocked: Array = []) -> Dictionary:
	var purposes: Array = balance["visit_purposes"]
	var total := 0.0
	for p in purposes:
		total += _weight(p, hour, location_id, stocked)
	var roll := pick_rng.uniform_0_1() * total
	var chosen: Dictionary = purposes[0]
	var acc := 0.0
	for p in purposes:
		acc += _weight(p, hour, location_id, stocked)
		if roll < acc:
			chosen = p
			break
	var lo := int(chosen["budget_yen"][0])
	var hi := int(chosen["budget_yen"][1])
	var budget := _round10((lo + money_rng.uniform_0_1() * float(hi - lo)) * StoreLocation.budget_multiplier(location_id))
	var f_lo := float(chosen["wallet_factor"][0])
	var f_hi := float(chosen["wallet_factor"][1])
	var wallet := maxi(_round10(budget * (f_lo + money_rng.uniform_0_1() * (f_hi - f_lo))), budget)
	return {"purpose_id": chosen["purpose_id"], "budget_yen": budget, "wallet_yen": wallet, "slots": (chosen["targets"] as Array).size()}


static func _weight(p: Dictionary, hour: int, location_id: String, stocked: Array) -> float:
	if not stocked.is_empty():
		var first: Array = p["targets"][0]
		if not first.has(ANY) and not first.any(func(c): return stocked.has(c)):
			return 0.0
	return float(p["hour_weights"][hour]) * StoreLocation.purpose_multiplier(location_id, p["purpose_id"])


## Categories a target slot accepts (every category of the catalog for "any").
static func slot_categories(balance: Dictionary, purpose_id: String, slot: int, all_categories: Array) -> Array:
	var targets: Array = find(balance, purpose_id).get("targets", [])
	if slot < 0 or slot >= targets.size():
		return []
	var cats: Array = targets[slot]
	return all_categories.duplicate() if cats.has(ANY) else cats.duplicate()


## Probability that a customer of this purpose picks up an item it walks past (before price and budget checks).
static func impulse_probability(balance: Dictionary, purpose_id: String, category_preference: float, price_factor: float) -> float:
	var base := float(balance.get("impulse", {}).get("base_probability", 0.0))
	var k := float(find(balance, purpose_id).get("impulse", 1.0))
	return clampf(base * k * category_preference * price_factor, 0.0, 1.0)


static func max_impulse(balance: Dictionary) -> int:
	return int(balance.get("impulse", {}).get("max_per_visit", 0))


static func _round10(v: float) -> int:
	return int(round(v / 10.0)) * 10
