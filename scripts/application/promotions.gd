class_name Promotions
extends RefCounted
## Store promotions, phase 1 (issue #137): price sales and bundles from data/promotions/promotions_v1.json.
## A running promotion is {promotion_id, def_id, start_day, end_day} in state.promotions (inclusive days).
##   - price: the SKUs of its categories sell at a fixed price or a percentage off (rounded to 10 yen, never above
##     the list price), optionally only between hours[0] and hours[1]. GameState.sell_price is this effective price,
##     so the purchase decision, the budget and the booked revenue all see it; it never raises the visitor count.
##   - bundle: a basket with one item of every group gets discount_yen once, booked at the till as a DISCOUNT row
##     (an expense, since ledger amounts are never negative; it comes off the operating profit like 販促費).
##   - multi / second_half (phase 2): a customer who picks an item of its categories may take more of the same
##     item (extra_take per extra unit, up to max_units); at the till a basket with n units of the categories gets
##     the best tier's yen off (multi: [[2, 40], [3, 90]]) or half the lower price of every pair (second_half),
##     booked as a DISCOUNT row like a bundle.
##   - coupon (phase 2): a basket with an item of its categories gets one coupon for the next visit (coupon_yen off
##     an item of those categories, valid valid_days days, state.coupons). An outstanding coupon brings its holder
##     back with return_rate over its days (DemandGenerator); at the till a basket of the categories redeems it
##     (DISCOUNT row); unused coupons expire. A free_item coupon ("buy one, the next one free") takes the price of the
##     cheapest unit of its categories in the basket instead of coupon_yen (the sale keeps its revenue and cost). Issued and redeemed coupons are counted per promotion.
##   - volume_up (phase 2): its skus are separate products in the catalog (more in the pack, the same price, a
##     higher cost and pull); they can be ordered only while the campaign runs (stock already bought still sells).
##   - collab (#140 phase 2): a fair with limited goods: its skus can be ordered only while it runs (like volume_up),
##     its categories pull more and a few more people come (like a fair).
##   - gift / stamps / fair (#140 phase 1): purchase bonuses and fairs. gift: a basket with need_units of its
##     categories gets one novelty while the stock lasts (customers may take more to reach it, extra_take; its
##     categories pull more while it lasts). stamps: every card_every-th basket of its categories gets a stamp card
##     with one stamp (kept in state.coupons with yen 0 and `stamps`); holders come back like coupon holders and get a
##     stamp per basket of the categories; stamps_needed stamps earn the prize while the stock lasts; cards end with
##     the campaign. fair: its categories pull more (pulls) and a few more people come (visitors). The novelties are
##     bought at the start (stock x novelty_cost_yen, with the setup cost); nothing is booked when one is handed out.
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


## A percent-off price on the 10 yen grid. A cheap item that would round back to its list price keeps the exact price.
static func percent_price(list: int, percent_off: float) -> int:
	var exact := float(list) * (100.0 - percent_off) / 100.0
	var rounded := int(round(exact / 10.0)) * 10
	return rounded if rounded < list or percent_off <= 0.0 else int(round(exact))


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
			price = percent_price(list, float(d["percent_off"]))
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


## The running multi-buy deal (multi or second_half) covering a category: its definition plus promotion_id, or {}.
static func multi_for(state: GameState, category: String) -> Dictionary:
	for p in running(state):
		var d := definition(p["def_id"])
		if d.get("kind", "") == "gift" and int(d["need_units"]) > 1 and (d["categories"] as Array).has(category) and _stock_left(state, p["promotion_id"]) > 0:
			var g := d.duplicate()   # #140: take more to reach the gift
			g["max_units"] = int(d["need_units"])
			g["promotion_id"] = p["promotion_id"]
			return g
		if ["multi", "second_half"].has(d.get("kind", "")) and (d["categories"] as Array).has(category):
			var out := d.duplicate()
			out["promotion_id"] = p["promotion_id"]
			return out
	return {}


## Multi-buy discounts a basket earns: [{promotion_id, yen, units}] for every running multi / second_half deal whose
## categories the basket holds enough units of. `units`: [{category, price}] (one per unit sold).
static func multi_discounts(state: GameState, units: Array) -> Array:
	var out: Array = []
	for p in running(state):
		var d := definition(p["def_id"])
		if not ["multi", "second_half"].has(d.get("kind", "")):
			continue
		var prices: Array = units.filter(func(u): return (d["categories"] as Array).has(u["category"])).map(func(u): return int(u["price"]))
		var yen := 0
		if d["kind"] == "multi":
			for tier in d["tiers"]:
				if prices.size() >= int(tier[0]):
					yen = maxi(yen, int(tier[1]))
		else:
			prices.sort()
			prices.reverse()
			for i in prices.size() / 2:
				yen += int(prices[2 * i + 1]) / 2   # half the lower price of each pair
		if yen > 0:
			out.append({"promotion_id": p["promotion_id"], "yen": yen, "units": prices.size()})
	return out


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
	var cost := int(d.get("setup_cost_yen", 0)) + int(d.get("stock", 0)) * int(d.get("novelty_cost_yen", 0))   # #140: the novelties
	state.next_promotion_seq += 1
	var id := "promo_%03d" % state.next_promotion_seq
	if cost > 0 and not state.ledger.record("PROMO", "%s:PROMO" % command_id, -cost, state.day, state.time_sec, {"promotion_id": id, "def_id": def_id}, {"expense": cost}):
		state.next_promotion_seq -= 1
		return "not_enough_cash"
	state.promotions.append({"promotion_id": id, "def_id": def_id, "start_day": state.day, "end_day": state.day + days - 1})
	state.promo_stats[id] = {"units": 0, "discount_yen": 0}
	if d.has("stock"):
		state.promo_stats[id]["stock"] = int(d["stock"])
	return ""


## Novelties left of a gift / stamps campaign.
static func _stock_left(state: GameState, promotion_id: String) -> int:
	return int((state.promo_stats.get(promotion_id, {}) as Dictionary).get("stock", 0))


## Hands one novelty of a campaign out (stock - 1). -> false when none is left.
static func _hand_out(state: GameState, promotion_id: String) -> bool:
	var st: Dictionary = state.promo_stats.get(promotion_id, {})
	if int(st.get("stock", 0)) <= 0:
		return false
	st["stock"] = int(st["stock"]) - 1
	st["given"] = int(st.get("given", 0)) + 1
	if int(st["stock"]) == 0:
		state.emit_event("NOVELTY_GONE", {"promotion_id": promotion_id})
	return true


## Gifts a basket earns at the till (#140): one novelty per running gift whose categories the basket holds
## need_units of, while its stock lasts. `units`: [{category, price}] per unit sold. -> the novelty names handed out.
static func give_gifts(state: GameState, units: Array) -> Array:
	var out: Array = []
	for p in running(state):
		var d := definition(p["def_id"])
		if d.get("kind", "") != "gift":
			continue
		var n := units.filter(func(u): return (d["categories"] as Array).has(u["category"])).size()
		if n >= int(d["need_units"]) and _hand_out(state, p["promotion_id"]):
			out.append(String(d["novelty_name"]))
	return out


## Pull of a category from the running fairs and the gifts with novelties left (#140; 1 without).
static func category_pull(state: GameState, category: String) -> float:
	var k := 1.0
	for p in running(state):
		var d := definition(p["def_id"])
		match String(d.get("kind", "")):
			"fair", "collab":
				k *= float((d["pulls"] as Dictionary).get(category, 1.0))
			"gift":
				if (d["categories"] as Array).has(category) and _stock_left(state, p["promotion_id"]) > 0:
					k *= float(d.get("pull", 1.0))
	return k


## Visitors brought by the running fairs (#140; 1 without).
static func visitor_factor(state: GameState) -> float:
	var k := 1.0
	for p in running(state):
		var d := definition(p["def_id"])
		if ["fair", "collab"].has(d.get("kind", "")):
			k *= float(d.get("visitors", 1.0))
	return k


## Ends a running promotion now (it stays in the list as finished). -> "" or an error key.
static func stop(state: GameState, promotion_id: String) -> String:
	for p in state.promotions:
		if p["promotion_id"] == promotion_id and int(p["end_day"]) >= state.day:
			p["end_day"] = state.day - 1
			return ""
	return "unknown_promotion"


## Can this SKU be ordered now? Volume-up products only while their campaign runs.
static func orderable(state: GameState, sku_id: String) -> bool:
	var campaign_only := false
	for d in data()["promotions"]:
		if ["volume_up", "collab"].has(d.get("kind", "")) and (d["skus"] as Array).has(sku_id):
			campaign_only = true
			for p in running(state):
				if p["def_id"] == d["def_id"]:
					return true
	return not campaign_only


## The running coupon promotion covering any of these categories (its definition plus promotion_id), or {}.
static func coupon_for(state: GameState, categories: Array) -> Dictionary:
	for p in running(state):
		var d := definition(p["def_id"])
		if d.get("kind", "") == "coupon" and (d["categories"] as Array).any(func(c): return categories.has(c)):
			var out := d.duplicate()
			out["promotion_id"] = p["promotion_id"]
			return out
	return {}


## Issues one coupon for a basket of these categories (when a coupon promotion covers one), and a stamp card (#140)
## for every card_every-th basket of a running stamp rally's categories while its prizes last (not of `skip_def`,
## the rally whose card the customer brought). -> the coupon (or else the card) issued, or {}.
static func issue_coupon(state: GameState, categories: Array, skip_def := "") -> Dictionary:
	var out := {}
	var d := coupon_for(state, categories)
	if not d.is_empty():
		state.next_coupon_seq += 1
		out = {"coupon_id": "cpn_%05d" % state.next_coupon_seq, "promotion_id": d["promotion_id"], "def_id": d["def_id"],
			"expires_day": state.day + int(d["valid_days"]), "yen": int(d["coupon_yen"]), "returning": false}
		state.coupons.append(out)
		var st: Dictionary = state.promo_stats.get(d["promotion_id"], {})
		st["issued"] = int(st.get("issued", 0)) + 1
	for p in running(state):
		var r := definition(p["def_id"])
		if r.get("kind", "") != "stamps" or r["def_id"] == skip_def or not (r["categories"] as Array).any(func(c): return categories.has(c)):
			continue
		var st: Dictionary = state.promo_stats.get(p["promotion_id"], {})
		st["eligible"] = int(st.get("eligible", 0)) + 1
		if (int(st["eligible"]) - 1) % int(r["card_every"]) != 0 or _stock_left(state, p["promotion_id"]) <= 0:
			continue
		state.next_coupon_seq += 1
		var card := {"coupon_id": "cpn_%05d" % state.next_coupon_seq, "promotion_id": p["promotion_id"], "def_id": r["def_id"],
			"expires_day": int(p["end_day"]), "yen": 0, "returning": false, "stamps": 1}
		state.coupons.append(card)
		st["issued"] = int(st.get("issued", 0)) + 1
		st["stamps"] = int(st.get("stamps", 0)) + 1
		if out.is_empty():
			out = card
	return out


## Redeems `coupon_id` against a basket (`units`: [{category, price}] per unit sold). -> yen off (0 = not usable
## here; the coupon stays): coupon_yen, or for a free_item coupon the price of the cheapest unit of its categories.
static func redeem_coupon(state: GameState, coupon_id: String, units: Array) -> int:
	var categories: Array = units.map(func(u): return u["category"])
	for i in state.coupons.size():
		var c: Dictionary = state.coupons[i]
		if c["coupon_id"] != coupon_id:
			continue
		c["returning"] = false
		if int(c["expires_day"]) < state.day or not (definition(c["def_id"]).get("categories", []) as Array).any(func(x): return categories.has(x)):
			return 0
		var d := definition(c["def_id"])
		if d.get("kind", "") == "stamps":   # #140: a stamp; the prize at stamps_needed while the stock lasts
			var sst: Dictionary = state.promo_stats.get(c["promotion_id"], {})
			c["stamps"] = int(c.get("stamps", 0)) + 1
			sst["stamps"] = int(sst.get("stamps", 0)) + 1
			if int(c["stamps"]) >= int(d["stamps_needed"]):
				state.coupons.remove_at(i)
				if _hand_out(state, c["promotion_id"]):
					sst["redeemed"] = int(sst.get("redeemed", 0)) + 1
				else:
					sst["prize_out"] = int(sst.get("prize_out", 0)) + 1
			return 0
		var yen := int(c["yen"])
		if bool(d.get("free_item", false)):
			var prices: Array = units.filter(func(u): return (d["categories"] as Array).has(u["category"])).map(func(u): return int(u["price"]))
			yen = prices.min()
		state.coupons.remove_at(i)
		var st: Dictionary = state.promo_stats.get(c["promotion_id"], {})
		st["redeemed"] = int(st.get("redeemed", 0)) + 1
		st["discount_yen"] = int(st.get("discount_yen", 0)) + yen
		return yen
	return 0


## Drops the coupons past their last day (at midnight); a holder who came back and left without paying may come again.
static func expire_coupons(state: GameState) -> void:
	state.coupons = state.coupons.filter(func(c): return int(c["expires_day"]) >= state.day)
	for c in state.coupons:
		c["returning"] = false


## Probability, per step, that one of the outstanding coupons (not already on its way back) brings its holder back:
## each coupon's return_rate spread over its valid days. -> {p, coupon_id (the oldest waiting one)}.
static func coupon_return(state: GameState) -> Dictionary:
	var p := 0.0
	var first := ""
	var steps_per_day := float(DemandModel.SECONDS_PER_DAY) / GameClock.STEP_GAME_SECONDS
	for c in state.coupons:
		if bool(c["returning"]):
			continue
		var d := definition(c["def_id"])
		p += float(d.get("return_rate", 0.0)) / maxf(float(d.get("valid_days", 1)), 1.0) / steps_per_day
		if first == "":
			first = c["coupon_id"]
	return {"p": minf(p, 0.5), "coupon_id": first}


## Books the deal of a sold unit (called by the sale): units and the discount against the list price.
static func note_sale(state: GameState, promotion_id: String, qty: int, discount: int) -> void:
	if promotion_id == "" or not state.promo_stats.has(promotion_id):
		return
	state.promo_stats[promotion_id]["units"] = int(state.promo_stats[promotion_id]["units"]) + qty
	state.promo_stats[promotion_id]["discount_yen"] = int(state.promo_stats[promotion_id]["discount_yen"]) + discount
