class_name Promotions
extends RefCounted
## Store promotions, phase 1 (issue #137): price sales and bundles from data/promotions/promotions_v1.json.
## A running promotion is {promotion_id, def_id, start_day, end_day} in state.promotions (inclusive days).
##   - price: the SKUs of its categories sell at a fixed price or a percentage off (rounded to 10 yen, never above
##     the list price), optionally only between hours[0] and hours[1]. GameState.sell_price is this effective price,
##     so the purchase decision, the budget and the booked revenue all see it; it never raises the visitor count.
##   - bundle: a basket with one item of every group gets discount_yen once, booked at the till as a DISCOUNT row
##     (an expense, since ledger amounts are never negative; it comes off the operating profit like 販促費).
## Starting one books its setup cost (POP, signs) as a PROMO expense. Results per promotion: units sold on the deal
## and the discount given (state.promo_stats).

const PATH := "res://data/promotions/promotions_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"promotions": [], "max_active": 0}
	return _data


static func definition(def_id: String) -> Dictionary:
	for d in data()["promotions"]:
		if d["def_id"] == def_id:
			return d
	return {}


static func running(state: GameState) -> Array:
	return state.promotions.filter(func(p): return int(p["start_day"]) <= state.day and state.day <= int(p["end_day"]))


## The effective price of a SKU now: the lowest of the running price promotions that cover it (in their hours),
## or the list price. -> {price, promotion_id}.
static func price_now(state: GameState, sku_id: String, list: int) -> Dictionary:
	var best := {"price": list, "promotion_id": ""}
	var sku := state.products.get_sku(sku_id)
	if sku.is_empty():
		return best
	var hour := DemandModel.hour_of_day(state.time_sec)
	for p in running(state):
		var d := definition(p["def_id"])
		if d.get("kind", "") != "price" or not (d["categories"] as Array).has(sku["category"]):
			continue
		if d.has("hours") and not (hour >= int(d["hours"][0]) and hour < int(d["hours"][1])):
			continue
		var price := list
		if d.has("fixed_price_yen"):
			price = int(d["fixed_price_yen"])
		elif d.has("percent_off"):
			price = int(round(float(list) * (100.0 - float(d["percent_off"])) / 100.0 / 10.0)) * 10
		price = clampi(price, 1, list)
		if price < int(best["price"]):
			best = {"price": price, "promotion_id": p["promotion_id"]}
	return best


## The running price promotion that covers a category (its hours aside: a unit reserved inside the window keeps
## its price at the till), or "".
static func price_promotion_for(state: GameState, category: String) -> String:
	for p in running(state):
		var d := definition(p["def_id"])
		if d.get("kind", "") == "price" and (d["categories"] as Array).has(category):
			return p["promotion_id"]
	return ""


## The best running bundle a basket of these categories earns. -> {promotion_id, yen} or {}.
static func bundle_for(state: GameState, categories: Array) -> Dictionary:
	var best := {}
	for p in running(state):
		var d := definition(p["def_id"])
		if d.get("kind", "") != "bundle":
			continue
		var ok := true
		for group in d["bundle"]:
			if not (group as Array).any(func(c): return categories.has(c)):
				ok = false
		if ok and (best.is_empty() or int(d["discount_yen"]) > int(best["yen"])):
			best = {"promotion_id": p["promotion_id"], "yen": int(d["discount_yen"])}
	return best


## Starts a promotion today for `days` days. -> "" or an error key.
static func start(state: GameState, command_id: String, def_id: String, days: int) -> String:
	var d := definition(def_id)
	if d.is_empty():
		return "unknown_promotion"
	if days < 1 or days > 14:
		return "days_invalid"
	var live := running(state)
	if live.any(func(p): return p["def_id"] == def_id):
		return "promotion_running"
	if live.size() >= int(data().get("max_active", 3)):
		return "too_many_promotions"
	var cost := int(d.get("setup_cost_yen", 0))
	state.next_promotion_seq += 1
	var id := "promo_%03d" % state.next_promotion_seq
	if cost > 0 and not state.ledger.record("PROMO", "%s:PROMO" % command_id, -cost, state.day, state.time_sec, {"promotion_id": id, "def_id": def_id}, {"expense": cost}):
		state.next_promotion_seq -= 1
		return "not_enough_cash"
	state.promotions.append({"promotion_id": id, "def_id": def_id, "start_day": state.day, "end_day": state.day + days - 1})
	state.promo_stats[id] = {"units": 0, "discount_yen": 0}
	return ""


## Ends a running promotion now (it stays in the list as finished). -> "" or an error key.
static func stop(state: GameState, promotion_id: String) -> String:
	for p in state.promotions:
		if p["promotion_id"] == promotion_id and int(p["end_day"]) >= state.day:
			p["end_day"] = state.day - 1
			return ""
	return "unknown_promotion"


## Books the deal of a sold unit (called by the sale): units and the discount against the list price.
static func note_sale(state: GameState, promotion_id: String, qty: int, discount: int) -> void:
	if promotion_id == "" or not state.promo_stats.has(promotion_id):
		return
	state.promo_stats[promotion_id]["units"] = int(state.promo_stats[promotion_id]["units"]) + qty
	state.promo_stats[promotion_id]["discount_yen"] = int(state.promo_stats[promotion_id]["discount_yen"]) + discount
