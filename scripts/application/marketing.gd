class_name Marketing
extends RefCounted
## Media advertising, phase 1 (issue #136, docs/design/MARKETING_CAMPAIGNS_PHASE1.md): newspaper, radio, web ads and
## television campaigns from data/marketing/media_v1.json, beside the #18 tiers (general awareness).
##   - BOOK: the setup cost is paid at once (AD_SETUP); airing starts after the medium's lead days and lasts its
##     days. CANCEL before the start: no refund of the setup cost.
##   - Every airing day (BusinessService.charge_day, once per day) books its cost (AD_MEDIA "<day>:MEDIA:<id>") when
##     cash allows; an unpaid day has no effect and no debt. The effect stock then moves once per day:
##     A = carry x A + gain (gain 1 per paid day; web ads 1.5 x (1 - exp(-budget / 1000))), so effects ramp up,
##     peak and fade after the end.
##   - Lift of a campaign in an hour it works: max_lift x (1 - exp(-A / saturation)). The tier's own lift
##     (multiplier - 1) joins the same pool, capped at lift_cap; with the day's event traffic the total demand
##     multiplier is capped at traffic_cap. Without campaigns the visitors are exactly those of the tier alone.
##   - Category pull while a campaign works: newspaper / radio boosts, web ads its target category; capped at
##     category_cap together with the day's event. Television raises the reputation by 1 per paid day (at most 3
##     per campaign).

const PATH := "res://data/marketing/media_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"media": []}
	return _data


static func medium(id: String) -> Dictionary:
	for m in data()["media"]:
		if m["medium"] == id:
			return m
	return {}


## Campaigns booked or airing (the ones counted against max_active).
static func active(state: GameState) -> Array:
	return state.campaigns.filter(func(c): return c["status"] == "booked" and int(c["end_day"]) >= state.day)


## Books a campaign. -> "" or an error key.
static func book(state: GameState, command_id: String, medium_id: String, days: int, budget_yen: int = 0, category: String = "") -> String:
	var m := medium(medium_id)
	if m.is_empty():
		return "unknown_medium"
	if days < int(m["min_days"]) or days > int(m["max_days"]):
		return "days_invalid"
	if active(state).size() >= int(data().get("max_active", 4)):
		return "too_many_campaigns"
	var daily := int(m["cost_per_day_yen"])
	if medium_id == "web_ads":
		daily = budget_yen if budget_yen > 0 else daily
		if daily < int(m["budget_min_yen"]) or daily > int(m["budget_max_yen"]):
			return "budget_invalid"
		if category != "" and not ProductCatalog.CATEGORIES.has(category):
			return "unknown_category"
	var setup := int(m["setup_cost_yen"])
	if setup > state.cash_yen:
		return "not_enough_cash"
	state.next_campaign_seq += 1
	var id := "cmp_%05d" % state.next_campaign_seq
	if setup > 0 and not state.ledger.record("AD_SETUP", "cmp:%s:setup" % id, -setup, state.day, state.time_sec, {"campaign_id": id, "medium": medium_id}, {"expense": setup}):
		state.next_campaign_seq -= 1
		return "not_enough_cash"
	var start := state.day + int(m["lead_days"])
	state.campaigns.append({"campaign_id": id, "medium": medium_id, "category": category if medium_id == "web_ads" else "",
		"daily_budget_yen": daily, "setup_cost_yen": setup, "booked_day": state.day, "start_day": start, "end_day": start + days - 1,
		"status": "booked", "spent_yen": setup, "paid_days": [], "stock": 0.0, "stock_day": -1, "reputation_added": 0})
	return ""


## Cancels a campaign that has not started (the setup cost is not refunded). -> "" or an error key.
static func cancel(state: GameState, campaign_id: String) -> String:
	for c in state.campaigns:
		if c["campaign_id"] == campaign_id:
			if c["status"] != "booked" or int(c["start_day"]) <= state.day:
				return "campaign_started"
			c["status"] = "cancelled"
			return ""
	return "unknown_campaign"


## The day's media charges and effect stocks (called from BusinessService.charge_day, once per day).
static func charge_day(state: GameState, day: int) -> void:
	for c in state.campaigns:
		if int(c["stock_day"]) >= day or c["status"] == "cancelled":
			continue
		var m := medium(c["medium"])
		var gain := 0.0
		if c["status"] == "booked" and int(c["start_day"]) <= day and day <= int(c["end_day"]):
			var cost := int(c["daily_budget_yen"])
			var id := "%d:MEDIA:%s" % [day, c["campaign_id"]]
			if state.ledger.has_event(id) or (cost <= state.cash_yen and state.ledger.record("AD_MEDIA", id, -cost, day, state.time_sec, {"campaign_id": c["campaign_id"], "medium": c["medium"]}, {"expense": cost})):
				if not (c["paid_days"] as Array).has(day):
					(c["paid_days"] as Array).append(day)
					c["spent_yen"] = int(c["spent_yen"]) + cost
				gain = 1.5 * (1.0 - exp(-float(cost) / 1000.0)) if c["medium"] == "web_ads" else 1.0
				if int(m.get("reputation_per_day", 0)) > 0 and int(c["reputation_added"]) < int(m.get("reputation_max", 0)):
					state.reputation = clampi(state.reputation + int(m["reputation_per_day"]), 0, 100)
					c["reputation_added"] = int(c["reputation_added"]) + int(m["reputation_per_day"])
		c["stock"] = snappedf(float(m["carry"]) * float(c["stock"]) + gain, 0.0001)
		c["stock_day"] = day
		if day > int(c["end_day"]) and float(c["stock"]) < 0.01:
			c["status"] = "ended"
			c["stock"] = 0.0


## Lift of one campaign in `hour` (0 outside its hours or once it has faded).
static func campaign_lift(c: Dictionary, hour: int) -> float:
	if c["status"] == "cancelled" or float(c["stock"]) <= 0.0:
		return 0.0
	var m := medium(c["medium"])
	var hours: Array = (m.get("hours", []) as Array).map(func(h): return int(h))   # JSON numbers are floats
	if not hours.is_empty() and not hours.has(hour):
		return 0.0
	return float(m["max_lift"]) * (1.0 - exp(-float(c["stock"]) / float(m["saturation"])))


## The demand multiplier of advertising in `hour`: 1 + min(lift_cap, tier lift + campaign lifts), held so that
## with the day's event traffic the total stays within traffic_cap. Without campaigns: the tier's multiplier.
static func ad_factor(state: GameState, hour: int, tier_multiplier: float, event_traffic: float) -> float:
	if state.campaigns.is_empty():
		return tier_multiplier
	var lift := tier_multiplier - 1.0
	for c in state.campaigns:
		lift += campaign_lift(c, hour)
	var factor := 1.0 + minf(float(data().get("lift_cap", 0.6)), lift)
	if event_traffic > 0.0:
		factor = minf(factor, float(data().get("traffic_cap", 2.0)) / event_traffic)
	return factor


## Pull of a category from the campaigns working now (1 = none); with the event's own multiplier capped by the caller.
static func category_multiplier(state: GameState, category: String) -> float:
	if state.campaigns.is_empty():
		return 1.0
	var k := 1.0
	for c in state.campaigns:
		if c["status"] == "cancelled" or float(c["stock"]) <= 0.0:
			continue
		var m := medium(c["medium"])
		var strength := 1.0 - exp(-float(c["stock"]) / float(m["saturation"]))
		if c["medium"] == "web_ads":
			if c["category"] == category:
				k *= 1.0 + (float(m["target_boost"]) - 1.0) * strength
		elif (m.get("category_boost", {}) as Dictionary).has(category):
			k *= 1.0 + (float(m["category_boost"][category]) - 1.0) * strength
	return k


## For the 媒体広告 card: every medium, and the campaigns (newest first) with their state and today's lift.
static func views(state: GameState) -> Dictionary:
	var hour := DemandModel.hour_of_day(state.time_sec)
	var list: Array = []
	for c in state.campaigns:
		var v: Dictionary = c.duplicate(true)
		v["display_name"] = medium(c["medium"]).get("display_name", c["medium"])
		v["phase"] = "cancelled" if c["status"] == "cancelled" else ("ended" if c["status"] == "ended" or state.day > int(c["end_day"]) and float(c["stock"]) < 0.01 else ("airing" if state.day >= int(c["start_day"]) and state.day <= int(c["end_day"]) else ("fading" if state.day > int(c["end_day"]) else "booked")))
		v["lift_now"] = snappedf(campaign_lift(c, hour), 0.001)
		list.push_front(v)
	return {"media": data()["media"], "campaigns": list, "max_active": int(data().get("max_active", 4)), "active": active(state).size()}
