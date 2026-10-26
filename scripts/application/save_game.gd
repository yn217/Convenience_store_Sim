class_name SaveGame
extends RefCounted
## savegame.schema.json v1 <-> GameState (04 §8, 09 §6, 12 §5).
## `to_dict` is the only writer; `from_dict` builds a brand-new GameState, validates it and
## returns {ok, state, errors}. The caller's current state is never touched, so a rejected file
## changes nothing. Fields the schema has no slot for live in the optional `runtime_state`
## object and in optional customer keys (docs/schemas/savegame.schema.json, added with #20).

## 2 = basket purchases (issue #128): customers may hold several reservations and carry basket_size /
## basket_wishes. Schema 1 files still load: every customer gets basket_size 1 and no wishes.
## 3 = visit purposes (issue #141): customers carry an optional `visit` object (purpose, budget, wallet, basket
## log, impulse state); rng_states gain `visits` and `impulse`. Schema 1/2 files still load: their customers have
## no purpose (they finish the visit with the #128 basket) and the new streams start from the default seeds.
const SCHEMA_VERSION := 3
const OLDEST_LOADABLE_VERSION := 1
const DEFAULT_EVENTS_SEED := 345678
const REQUIRED := [
	"schema_version", "save_id", "saved_at_utc", "game_tick", "game_time_seconds", "speed_setting",
	"business_state", "rng_states", "store", "fixture_instances", "inventory_segments", "reservations",
	"customers", "economy", "advertising", "daily_reports", "applied_event_ids", "store_reputation",
	"product_price_overrides", "applied_command_ids", "gameplay_event_state", "progression_state",
]
const OPTIONAL := ["runtime_state"]
const PHASE_OUT := {
	"SELECT": "SELECT_SHELF", "WALK_SHELF": "WALK_TO_ACCESS", "WALK_REGISTER": "WALK_TO_REGISTER",
	"WAIT_QUEUE": "QUEUE", "QUEUE": "QUEUE", "CHECKOUT": "CHECKOUT", "EXIT": "EXIT",
	"APPROACH": "APPROACH", "ENTER": "ENTER", "WALK_AWAY": "WALK_AWAY",
}
const PHASE_IN := {
	"SELECT_SHELF": "SELECT", "WALK_TO_ACCESS": "WALK_SHELF", "WALK_TO_REGISTER": "WALK_REGISTER",
	"QUEUE": "QUEUE", "CHECKOUT": "CHECKOUT", "EXIT": "EXIT",
	"APPROACH": "APPROACH", "ENTER": "ENTER", "WALK_AWAY": "WALK_AWAY",
}
const STATES := ["SETUP", "OPEN", "CLOSING", "PAYMENT_BLOCKED"]


# ---------------------------------------------------------------- state -> dictionary

static func to_dict(state: GameState, save_id: String, saved_at_utc: String) -> Dictionary:
	var grid := state.grid.to_save()
	var charged_day := -1
	for tx in state.ledger.transactions:
		if tx["event_type"] == "AD" and state.ledger.is_mine(tx):
			charged_day = maxi(charged_day, int(tx["day_index"]))
	var customers: Array = []
	for c in state.customers:
		customers.append(_customer_out(c, state.time_sec, CustomerAI.queue_timeout_sec(state.balance)))
	var event_ids := state.ledger.applied_event_ids.keys()
	event_ids.sort()
	var rng := state.rng_states.duplicate()
	if not rng.has("events"):
		rng["events"] = DEFAULT_EVENTS_SEED
	return {
		"schema_version": SCHEMA_VERSION,
		"save_id": save_id,
		"saved_at_utc": saved_at_utc,
		"game_tick": state.time_sec / int(GameClock.STEP_GAME_SECONDS),
		"game_time_seconds": state.time_sec,
		"speed_setting": state.speed_setting,
		"business_state": String(state.business_state),
		"rng_states": rng,
		"store": grid["store"],
		"fixture_instances": grid["fixture_instances"],
		"inventory_segments": state.inventory_segments.duplicate(true),
		"reservations": state.reservations.duplicate(true),
		"customers": customers,
		"economy": {
			"cash_yen": state.ledger.cash_yen,
			"ledger_transactions": state.ledger.transactions.duplicate(true),
			"unpaid_cost_yen": state.unpaid_cost_yen,
		},
		"advertising": {
			"today_budget_yen": state.applied_ad_tier_yen,
			"next_day_budget_yen": state.next_day_ad_yen,
			"last_charged_day": charged_day,
		},
		"daily_reports": state.daily_reports.duplicate(true),
		"applied_event_ids": event_ids,
		"store_reputation": state.reputation,
		"product_price_overrides": state.product_price_overrides.duplicate(),
		"applied_command_ids": state.applied_command_ids.duplicate(),
		"gameplay_event_state": state.gameplay_event_state.duplicate(true),
		"progression_state": state.progression_state.duplicate(true),
		"runtime_state": {
			"id_counters": {
				"fixture": state.next_fixture_seq, "lot": state.next_lot_seq,
				"segment": state.next_segment_seq, "customer": state.next_customer_seq,
			},
			"visit_stats": state.visit_stats.duplicate(),
			"rate_stats": state.rate_stats.duplicate(),
			"last_nonzero_speed": state.last_nonzero_speed,
			"staff": state.staff.map(_staff_out),   # #143
			"next_staff_seq": state.next_staff_seq,
			"staff_candidates": state.staff_candidates.duplicate(true),   # #144
			"location_id": state.location_id,   # #148
			"map_id": state.map_id, "plot_id": state.plot_id,   # #150
			"store_id": state.store_id,   # #146
			"facilities": state.facilities.duplicate(), "facility_visits": state.facility_visits.duplicate(),   # #149
			"visitors_by_hour": state.visitors_by_hour.duplicate(), "visitors_by_hour_yesterday": state.visitors_by_hour_yesterday.duplicate(),   # #150
			"promotions": state.promotions.duplicate(true), "next_promotion_seq": state.next_promotion_seq,   # #137
			"promo_stats": state.promo_stats.duplicate(true),
			"coupons": state.coupons.duplicate(true), "next_coupon_seq": state.next_coupon_seq,   # #137 phase 2
			"campaigns": state.campaigns.duplicate(true), "next_campaign_seq": state.next_campaign_seq,   # #136
		},
	}


## The #141 part of a customer (empty purpose = a customer without one).
static func _visit_out(c: Dictionary) -> Dictionary:
	var log: Array = []
	for e in c.get("basket_log", []):
		log.append({"sku_id": e["sku_id"], "price_yen": int(e["price"]), "kind": e["kind"], "state": e["state"]})
	return {
		"purpose_id": String(c.get("purpose_id", "")), "budget_yen": int(c.get("budget_yen", 0)),
		"wallet_yen": int(c.get("wallet_yen", 0)), "planned_yen": int(c.get("planned_yen", 0)),
		"impulse_count": int(c.get("impulse_count", 0)), "basket_log": log,
		"seen_categories": (c.get("seen_categories", []) as Array).duplicate(),
		"impulse_tried": (c.get("impulse_tried", []) as Array).duplicate(),
		"segment_id": String(c.get("segment_id", "")),   # #149
		"coupon_id": String(c.get("coupon_id", "")),     # #137
	}


static func _xy(t: Vector2i) -> Dictionary:
	return {"x": t.x, "y": t.y}


static func _staff_out(s: Dictionary) -> Dictionary:
	var task: Dictionary = s["task"]
	return {
		"staff_id": s["staff_id"], "name": s["name"], "archetype": s["archetype"], "skills": s["skills"].duplicate(),
		"fatigue": float(s["fatigue"]), "phase": s["phase"], "position": _xy(s["tile"]),
		"route": (s["path"] as Array).map(_xy), "walk_progress": float(s["progress"]), "timer": int(s["timer"]), "carry": int(s["carry"]),
		"task": {} if task.is_empty() else {"fixture_id": task["fixture_id"], "slot_id": task["slot"]["slot_id"], "sku_id": task["sku_id"], "need": int(task["need"]), "access": _xy(task["access"])},
	}


## Staff from runtime_state (#143); a save without them keeps the starting staff of the balance.
static func _staff_in(s: GameState, rt: Dictionary, errs: Array[String]) -> void:
	if not rt.has("staff"):
		return
	if typeof(rt["staff"]) != TYPE_ARRAY:
		errs.append("runtime_state.staff: not_array")
		return
	s.staff.clear()
	for i in rt["staff"].size():
		var e = rt["staff"][i]
		var path := "runtime_state.staff[%d]" % i
		if typeof(e) != TYPE_DICTIONARY or not JsonCheck.is_nonempty_string(e.get("staff_id")) or not StaffAI.PHASES.has(e.get("phase")) \
				or typeof(e.get("skills")) != TYPE_DICTIONARY or typeof(e.get("position")) != TYPE_DICTIONARY or typeof(e.get("route")) != TYPE_ARRAY:
			errs.append(path + ": invalid")
			return
		var skills := {}
		for k in StaffAI.SKILLS:
			if not JsonCheck.is_int(e["skills"].get(k)):
				errs.append(path + ".skills: invalid")
				return
			skills[k] = clampi(int(e["skills"][k]), 1, 5)
		var route: Array[Vector2i] = []
		for p in e["route"]:
			route.append(Vector2i(int(p["x"]), int(p["y"])))
		var task := {}
		var t = e.get("task", {})
		if typeof(t) == TYPE_DICTIONARY and not t.is_empty():
			var inst_id := String(t.get("fixture_id", ""))
			var slot := {}
			if s.grid.instances.has(inst_id):
				for sl in s.fixtures.get_type(s.grid.instances[inst_id]["type_id"])["shelf_slots"]:
					if sl["slot_id"] == t.get("slot_id"):
						slot = sl
			if not slot.is_empty():
				task = {"fixture_id": inst_id, "slot": slot, "sku_id": String(t["sku_id"]), "need": int(t["need"]), "access": Vector2i(int(t["access"]["x"]), int(t["access"]["y"]))}
		s.staff.append({
			"staff_id": String(e["staff_id"]), "name": String(e.get("name", "")), "archetype": String(e.get("archetype", "")), "skills": skills,
			"fatigue": clampf(float(e.get("fatigue", 0.0)), 0.0, 100.0), "phase": String(e["phase"]),
			"tile": Vector2i(int(e["position"]["x"]), int(e["position"]["y"])), "path": route, "progress": float(e.get("walk_progress", 0.0)),
			"timer": int(e.get("timer", 0)), "task": task, "carry": int(e.get("carry", 0)) if not task.is_empty() else 0, "trail": [], "moved": 0,
		})
	s.next_staff_seq = maxi(int(rt.get("next_staff_seq", 0)), s.staff.size())
	if typeof(rt.get("staff_candidates")) == TYPE_ARRAY:
		s.staff_candidates.clear()
		for c in rt["staff_candidates"]:
			if typeof(c) == TYPE_DICTIONARY and JsonCheck.is_nonempty_string(c.get("candidate_id")) and typeof(c.get("skills")) == TYPE_DICTIONARY:
				var skills := {}
				for k in StaffAI.SKILLS:
					skills[k] = clampi(int(c["skills"].get(k, 3)), 1, 5)
				s.staff_candidates.append({"candidate_id": String(c["candidate_id"]), "name": String(c.get("name", "")), "archetype": String(c.get("archetype", "")), "skills": skills})


static func _customer_out(c: Dictionary, now_sec: int, patience_sec: int) -> Dictionary:
	var route: Array = []
	for p in c["path"]:
		route.append({"x": p.x, "y": p.y})
	var tile: Vector2i = c["tile"]
	return {
		"customer_id": c["customer_id"],
		"phase": PHASE_OUT[c["phase"]],
		"position": {"x": tile.x, "y": tile.y},
		"route": route,
		"route_index": 0,
		"reservation_ids": (c["reservation_ids"] as Array).duplicate(),
		"patience_remaining_sec": maxi(patience_sec - (now_sec - int(c["queue_since"])), 0) if not (c["reservation_ids"] as Array).is_empty() else patience_sec,
		"basket_size": int(c.get("basket_size", 1)),
		"basket_wishes": (c.get("wishes", []) as Array).map(func(w): return {"sku_id": w["sku_id"], "fixture_id": w["fixture_id"]}),
		"target_fixture_id": null if c["fixture_id"] == "" else c["fixture_id"],
		"browse_remaining_sec": maxi(int(c.get("browse_left", -1)), -1),
		"visit": _visit_out(c),
		"checkout_remaining_sec": maxi(int(c["checkout_left"]), 0),
		"target_sku_id": c["sku_id"] if c["sku_id"] != "" else null,
		"queue_slot": c["queue_slot"],
		"register_id": c["register_id"],
		"retries": c["retries"],
		"walk_progress": c["progress"],
		"queue_since_sec": c["queue_since"],
		"outcome": c["outcome"],
	}


# ---------------------------------------------------------------- dictionary -> state

## Result: {"ok": bool, "state": GameState or null, "errors": Array[String], "unsupported_version": bool}.
static func from_dict(data, balance: Dictionary, fixtures: FixtureCatalog, products: ProductCatalog) -> Dictionary:
	var errs: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		return _bad(["$: not_object"])
	if data.has("schema_version") and JsonCheck.is_int(data["schema_version"]) and int(data["schema_version"]) > SCHEMA_VERSION:
		var r := _bad(["schema_version: unsupported_schema_version"])
		r["unsupported_version"] = true
		return r
	errs.append_array(JsonCheck.key_errors(data, REQUIRED, OPTIONAL, "$"))
	if not errs.is_empty():
		return _bad(errs)
	if not JsonCheck.is_int(data["schema_version"]) or int(data["schema_version"]) < OLDEST_LOADABLE_VERSION or int(data["schema_version"]) > SCHEMA_VERSION:
		return _bad(["schema_version: invalid_schema_version"])
	_check_scalars(data, errs)
	if not errs.is_empty():
		return _bad(errs)
	var grid := StoreGrid.from_save(data["store"], data["fixture_instances"], fixtures)
	errs.append_array(grid.load_errors)
	if not errs.is_empty():
		return _bad(errs)
	errs.append_array(StockSegment.list_errors(data["inventory_segments"], products, fixtures, grid))
	if not errs.is_empty():
		return _bad(errs)
	var s := GameState.from_balance(balance, {}, fixtures, products)
	s.grid = grid
	_fill(s, data, errs)
	if errs.is_empty():
		errs.append_array(semantic_errors(s))
	if not errs.is_empty():
		return _bad(errs)
	return {"ok": true, "state": s, "errors": errs, "unsupported_version": false}


static func _bad(errs: Array[String]) -> Dictionary:
	return {"ok": false, "state": null, "errors": errs, "unsupported_version": false}


static func _check_scalars(d: Dictionary, errs: Array[String]) -> void:
	for k in ["game_tick", "game_time_seconds", "speed_setting", "store_reputation"]:
		if not JsonCheck.is_int(d[k]):
			errs.append("%s: not_integer" % k)
	if not errs.is_empty():
		return
	if int(d["game_time_seconds"]) < 0 or int(d["game_tick"]) < 0:
		errs.append("game_time_seconds: negative")
	if not GameState.SPEED_OPTIONS.has(int(d["speed_setting"])):
		errs.append("speed_setting: invalid")
	if int(d["store_reputation"]) < 0 or int(d["store_reputation"]) > 100:
		errs.append("store_reputation: out_of_range")
	if typeof(d["business_state"]) != TYPE_STRING or not STATES.has(d["business_state"]):
		errs.append("business_state: invalid")
	for k in ["save_id", "saved_at_utc"]:
		if not JsonCheck.is_nonempty_string(d[k]):
			errs.append("%s: empty" % k)
	for k in ["fixture_instances", "inventory_segments", "reservations", "customers", "daily_reports", "applied_event_ids", "applied_command_ids"]:
		if typeof(d[k]) != TYPE_ARRAY:
			errs.append("%s: not_array" % k)
	for k in ["rng_states", "store", "economy", "advertising", "product_price_overrides", "gameplay_event_state", "progression_state"]:
		if typeof(d[k]) != TYPE_DICTIONARY:
			errs.append("%s: not_object" % k)
	if not errs.is_empty():
		return
	for k in ["arrivals", "purchases", "visuals", "events"]:
		if not d["rng_states"].has(k) or not JsonCheck.is_int(d["rng_states"][k]) or int(d["rng_states"][k]) < 0 or int(d["rng_states"][k]) > 4294967295:
			errs.append("rng_states.%s: invalid" % k)
	var eco: Dictionary = d["economy"]
	errs.append_array(JsonCheck.key_errors(eco, ["cash_yen", "ledger_transactions", "unpaid_cost_yen"], [], "economy"))
	if errs.is_empty():
		if not JsonCheck.is_int(eco["cash_yen"]) or int(eco["cash_yen"]) < 0:
			errs.append("economy.cash_yen: invalid")
		if not JsonCheck.is_int(eco["unpaid_cost_yen"]) or int(eco["unpaid_cost_yen"]) < 0:
			errs.append("economy.unpaid_cost_yen: invalid")
		if typeof(eco["ledger_transactions"]) != TYPE_ARRAY:
			errs.append("economy.ledger_transactions: not_array")
	var ad: Dictionary = d["advertising"]
	errs.append_array(JsonCheck.key_errors(ad, ["today_budget_yen", "next_day_budget_yen", "last_charged_day"], [], "advertising"))
	if errs.is_empty():
		for k in ["today_budget_yen", "next_day_budget_yen"]:
			if not JsonCheck.is_int(ad[k]) or int(ad[k]) < 0:
				errs.append("advertising.%s: invalid" % k)
		if not JsonCheck.is_int(ad["last_charged_day"]) or int(ad["last_charged_day"]) < -1:
			errs.append("advertising.last_charged_day: invalid")
	for sku_id in d["product_price_overrides"]:
		var price = d["product_price_overrides"][sku_id]
		if not JsonCheck.is_int(price) or int(price) < 1:
			errs.append("product_price_overrides.%s: invalid" % sku_id)


static func _fill(s: GameState, d: Dictionary, errs: Array[String]) -> void:
	s.time_sec = int(d["game_time_seconds"])
	s.day = s.time_sec / DemandModel.SECONDS_PER_DAY
	s.speed_setting = int(d["speed_setting"])
	s.business_state = StringName(d["business_state"])
	s.reputation = int(d["store_reputation"])
	for k in d["rng_states"]:
		s.rng_states[k] = int(d["rng_states"][k])
	s.ledger.cash_yen = int(d["economy"]["cash_yen"])
	s.unpaid_cost_yen = int(d["economy"]["unpaid_cost_yen"])
	var seen_events := {}
	for i in d["economy"]["ledger_transactions"].size():
		var tx = d["economy"]["ledger_transactions"][i]
		var tx_errs := _transaction_errors(tx, "economy.ledger_transactions[%d]" % i)
		errs.append_array(tx_errs)
		if not tx_errs.is_empty():
			continue
		if seen_events.has(tx["event_id"]):
			errs.append("economy.ledger_transactions[%d].event_id: duplicate_id" % i)
		seen_events[tx["event_id"]] = true
		s.ledger.transactions.append({
			"event_id": tx["event_id"], "event_type": tx["event_type"], "day_index": int(tx["day_index"]),
			"time_sec": int(tx["time_sec"]), "cash_delta_yen": int(tx["cash_delta_yen"]),
			"revenue_delta_yen": int(tx["revenue_delta_yen"]), "cogs_delta_yen": int(tx["cogs_delta_yen"]),
			"expense_delta_yen": int(tx["expense_delta_yen"]), "details": _ints_back(tx["details"]),
		})
	for id in d["applied_event_ids"]:
		if typeof(id) != TYPE_STRING or String(id).is_empty():
			errs.append("applied_event_ids: invalid")
		else:
			s.ledger.applied_event_ids[id] = true
	for tx_id in seen_events:
		if not s.ledger.applied_event_ids.has(tx_id):
			errs.append("applied_event_ids: missing %s" % tx_id)
	if d["applied_event_ids"].size() != s.ledger.applied_event_ids.size():
		errs.append("applied_event_ids: duplicate_id")
	var seen_cmd := {}
	for id in d["applied_command_ids"]:
		if typeof(id) != TYPE_STRING or String(id).is_empty() or seen_cmd.has(id):
			errs.append("applied_command_ids: invalid_or_duplicate")
		else:
			seen_cmd[id] = true
			s.applied_command_ids.append(id)
	s.applied_ad_tier_yen = int(d["advertising"]["today_budget_yen"])
	s.next_day_ad_yen = int(d["advertising"]["next_day_budget_yen"])
	for sku_id in d["product_price_overrides"]:
		s.product_price_overrides[sku_id] = int(d["product_price_overrides"][sku_id])
	for seg in d["inventory_segments"]:
		var copy: Dictionary = seg.duplicate(true)
		for k in ["unit_cost_yen", "physical_qty", "reserved_qty"]:
			copy[k] = int(copy[k])
		if copy["expires_at_sec"] != null:
			copy["expires_at_sec"] = int(copy["expires_at_sec"])
		s.inventory_segments.append(copy)
	for i in d["reservations"].size():
		var r = d["reservations"][i]
		var r_errs := JsonCheck.key_errors(r, ["reservation_id", "customer_id", "segment_id", "qty", "sell_unit_yen_snapshot", "cost_unit_yen_snapshot", "reservation_expires_at_sec"], [], "reservations[%d]" % i) if typeof(r) == TYPE_DICTIONARY else ["reservations[%d]: not_object" % i]
		errs.append_array(r_errs)
		if r_errs.is_empty():
			for k in ["qty", "sell_unit_yen_snapshot", "cost_unit_yen_snapshot", "reservation_expires_at_sec"]:
				if not JsonCheck.is_int(r[k]) or int(r[k]) < (1 if k == "qty" or k == "sell_unit_yen_snapshot" else 0):
					errs.append("reservations[%d].%s: invalid" % [i, k])
			var copy: Dictionary = r.duplicate()
			for k in ["qty", "sell_unit_yen_snapshot", "cost_unit_yen_snapshot", "reservation_expires_at_sec"]:
				copy[k] = int(copy[k])
			s.reservations.append(copy)
	for i in d["daily_reports"].size():
		var rep_errs := DailyReport.errors(d["daily_reports"][i])
		for e in rep_errs:
			errs.append("daily_reports[%d].%s" % [i, e])
		if rep_errs.is_empty():
			var rep := {}
			for k in DailyReport.FIELDS:
				rep[k] = int(d["daily_reports"][i][k])
			for k in DailyReport.OPTIONAL_FIELDS:   # older saves lack them
				if JsonCheck.is_int(d["daily_reports"][i].get(k)) and int(d["daily_reports"][i][k]) >= 0:
					rep[k] = int(d["daily_reports"][i][k])
			s.daily_reports.append(rep)
	for i in d["customers"].size():
		_customer_in(s, d["customers"][i], i, errs)
	s.gameplay_event_state = _normalized(d["gameplay_event_state"])
	s.progression_state = _normalized(d["progression_state"])
	var rt = d.get("runtime_state", {})
	if typeof(rt) != TYPE_DICTIONARY:
		errs.append("runtime_state: not_object")
		return
	_staff_in(s, rt, errs)
	if typeof(rt.get("promotions")) == TYPE_ARRAY:   # #137 (absent in older saves)
		for p in rt["promotions"]:
			if typeof(p) != TYPE_DICTIONARY or Promotions.definition(String(p.get("def_id", ""))).is_empty() or not JsonCheck.is_int(p.get("start_day")) or not JsonCheck.is_int(p.get("end_day")):
				errs.append("runtime_state.promotions: invalid")
				break
			s.promotions.append({"promotion_id": String(p.get("promotion_id", "")), "def_id": String(p["def_id"]), "start_day": int(p["start_day"]), "end_day": int(p["end_day"])})
		s.next_promotion_seq = int(rt.get("next_promotion_seq", s.promotions.size()))
		var st = rt.get("promo_stats", {})
		if typeof(st) == TYPE_DICTIONARY:
			for k in st:
				if typeof(st[k]) == TYPE_DICTIONARY:
					s.promo_stats[k] = {"units": int(st[k].get("units", 0)), "discount_yen": int(st[k].get("discount_yen", 0))}
					for extra in ["issued", "redeemed"]:   # coupon promotions
						if st[k].has(extra):
							s.promo_stats[k][extra] = int(st[k][extra])
	if typeof(rt.get("campaigns")) == TYPE_ARRAY:   # #136 (absent in older saves)
		for cp in rt["campaigns"]:
			if typeof(cp) != TYPE_DICTIONARY or Marketing.medium(String(cp.get("medium", ""))).is_empty() or not JsonCheck.is_int(cp.get("start_day")) or not JsonCheck.is_int(cp.get("end_day")) \
					or not ["booked", "cancelled", "ended"].has(cp.get("status")):
				errs.append("runtime_state.campaigns: invalid")
				break
			s.campaigns.append({"campaign_id": String(cp.get("campaign_id", "")), "medium": String(cp["medium"]), "category": String(cp.get("category", "")),
				"daily_budget_yen": int(cp.get("daily_budget_yen", 0)), "setup_cost_yen": int(cp.get("setup_cost_yen", 0)), "booked_day": int(cp.get("booked_day", 0)),
				"start_day": int(cp["start_day"]), "end_day": int(cp["end_day"]), "status": String(cp["status"]), "spent_yen": int(cp.get("spent_yen", 0)),
				"paid_days": (cp.get("paid_days", []) as Array).map(func(d): return int(d)), "stock": float(cp.get("stock", 0.0)), "stock_day": int(cp.get("stock_day", -1)),
				"reputation_added": int(cp.get("reputation_added", 0))})
		s.next_campaign_seq = int(rt.get("next_campaign_seq", s.campaigns.size()))
	if typeof(rt.get("coupons")) == TYPE_ARRAY:   # #137 phase 2 (absent in older saves)
		for cp in rt["coupons"]:
			if typeof(cp) != TYPE_DICTIONARY or Promotions.definition(String(cp.get("def_id", ""))).is_empty() or not JsonCheck.is_int(cp.get("expires_day")) or not JsonCheck.is_int(cp.get("yen")):
				errs.append("runtime_state.coupons: invalid")
				break
			s.coupons.append({"coupon_id": String(cp.get("coupon_id", "")), "promotion_id": String(cp.get("promotion_id", "")), "def_id": String(cp["def_id"]),
				"expires_day": int(cp["expires_day"]), "yen": int(cp["yen"]), "returning": bool(cp.get("returning", false))})
		s.next_coupon_seq = int(rt.get("next_coupon_seq", s.coupons.size()))
	if typeof(rt.get("plot_id")) == TYPE_STRING and String(rt["plot_id"]) != "":   # #150 (absent in older saves)
		if WorldMap.plot(String(rt.get("map_id", "")), String(rt["plot_id"])).is_empty():
			errs.append("runtime_state.plot_id: invalid")
		else:
			s.map_id = String(rt["map_id"])
			s.plot_id = String(rt["plot_id"])
	if typeof(rt.get("facilities")) == TYPE_ARRAY:   # #149 (absent in older saves)
		for fid in rt["facilities"]:
			if NearbyFacility.find(String(fid)).is_empty() or s.facilities.has(String(fid)) or s.facilities.size() >= NearbyFacility.max_count():
				errs.append("runtime_state.facilities: invalid")
				break
			s.facilities.append(String(fid))
		var fv = rt.get("facility_visits", {})
		if typeof(fv) == TYPE_DICTIONARY:
			for k in fv:
				if JsonCheck.is_int(fv[k]) and int(fv[k]) >= 0:
					s.facility_visits[String(k)] = int(fv[k])
	for k in ["visitors_by_hour", "visitors_by_hour_yesterday"]:   # #150 (absent in older saves)
		var arr = rt.get(k, [])
		if typeof(arr) == TYPE_ARRAY and (arr.size() == 0 or arr.size() == 24) and arr.all(func(x): return JsonCheck.is_int(x) and int(x) >= 0):
			s.set(k, arr.map(func(x): return int(x)))
	if typeof(rt.get("store_id")) == TYPE_STRING:   # #146 (absent in older saves: the first store)
		s.set_store_id(String(rt["store_id"]))
	var loc = rt.get("location_id", "")
	if typeof(loc) != TYPE_STRING or (loc != "" and StoreLocation.find(loc).is_empty()):
		errs.append("runtime_state.location_id: invalid")
	else:
		s.location_id = loc
	var counters = rt.get("id_counters", {})
	s.next_fixture_seq = _counter(counters, "fixture", _max_suffix(s.grid.instances.keys()), errs)
	s.next_lot_seq = _counter(counters, "lot", _max_suffix(s.inventory_segments.map(func(x): return x["lot_id"])), errs)
	s.next_segment_seq = _counter(counters, "segment", _max_suffix(s.inventory_segments.map(func(x): return x["segment_id"])), errs)
	s.next_customer_seq = _counter(counters, "customer", _max_suffix(s.customers.map(func(x): return x["customer_id"])), errs)
	var vs = rt.get("visit_stats", s.visit_stats)
	for k in s.visit_stats:
		if typeof(vs) != TYPE_DICTIONARY or not vs.has(k) or not JsonCheck.is_int(vs[k]) or int(vs[k]) < 0:
			errs.append("runtime_state.visit_stats.%s: invalid" % k)
		else:
			s.visit_stats[k] = int(vs[k])
	if typeof(vs) == TYPE_DICTIONARY and vs.has("balked") and JsonCheck.is_int(vs["balked"]) and int(vs["balked"]) >= 0:
		s.visit_stats["balked"] = int(vs["balked"])   # optional (#142): older saves have no turned-back count
	var rs = rt.get("rate_stats", s.rate_stats)
	for k in s.rate_stats:
		if typeof(rs) != TYPE_DICTIONARY or not rs.has(k) or not JsonCheck.is_int(rs[k]) or int(rs[k]) < 0:
			errs.append("runtime_state.rate_stats.%s: invalid" % k)
		else:
			s.rate_stats[k] = int(rs[k])
	if typeof(rs) == TYPE_DICTIONARY and rs.has("balked") and JsonCheck.is_int(rs["balked"]) and int(rs["balked"]) >= 0:
		s.rate_stats["balked"] = int(rs["balked"])   # optional (#142)
	var ln = rt.get("last_nonzero_speed", 1)
	if not JsonCheck.is_int(ln) or not [1, 2, 4].has(int(ln)):
		errs.append("runtime_state.last_nonzero_speed: invalid")
	else:
		s.last_nonzero_speed = int(ln)


static func _counter(counters, key: String, fallback: int, errs: Array[String]) -> int:
	if typeof(counters) != TYPE_DICTIONARY or not counters.has(key):
		return fallback
	if not JsonCheck.is_int(counters[key]) or int(counters[key]) < 0:
		errs.append("runtime_state.id_counters.%s: invalid" % key)
		return fallback
	return maxi(int(counters[key]), fallback)


## Highest numeric suffix among ids such as fx_0007 / seg_0012 (0 when none).
static func _max_suffix(ids: Array) -> int:
	var best := 0
	for id in ids:
		var parts := String(id).split("_")
		if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
			best = maxi(best, parts[parts.size() - 1].to_int())
	return best


static func _transaction_errors(tx, path: String) -> Array[String]:
	var errs := JsonCheck.key_errors(tx, ["event_id", "event_type", "day_index", "time_sec", "cash_delta_yen", "revenue_delta_yen", "cogs_delta_yen", "expense_delta_yen"], ["details"], path) if typeof(tx) == TYPE_DICTIONARY else ["%s: not_object" % path]
	if not errs.is_empty():
		return errs
	if not JsonCheck.is_nonempty_string(tx["event_id"]):
		errs.append("%s.event_id: empty" % path)
	if not ["ORDER", "SALE", "AD", "DAILY_FIXED", "ELECTRICITY", "WAGES", "PROMO", "DISCOUNT", "AD_SETUP", "AD_MEDIA", "WASTAGE", "FIXTURE_PURCHASE", "REVERSAL"].has(tx["event_type"]):
		errs.append("%s.event_type: unknown" % path)
	for k in ["day_index", "time_sec", "revenue_delta_yen", "cogs_delta_yen", "expense_delta_yen"]:
		if not JsonCheck.is_int(tx[k]) or int(tx[k]) < 0:
			errs.append("%s.%s: invalid" % [path, k])
	if not JsonCheck.is_int(tx["cash_delta_yen"]):
		errs.append("%s.cash_delta_yen: not_integer" % path)
	if tx.has("details") and typeof(tx["details"]) != TYPE_DICTIONARY:
		errs.append("%s.details: not_object" % path)
	return errs


## Whole-number floats (what JSON parsing yields) back to int, recursively.
static func _normalized(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if JsonCheck.is_int(v) else v
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _normalized(v[k])
			return out
		TYPE_ARRAY:
			var arr := []
			for x in v:
				arr.append(_normalized(x))
			return arr
	return v


## JSON numbers come back as floats; whole numbers in ledger details go back to int.
static func _ints_back(details) -> Dictionary:
	var out := {}
	if typeof(details) != TYPE_DICTIONARY:
		return out
	for k in details:
		var v = details[k]
		out[k] = int(v) if typeof(v) == TYPE_FLOAT and JsonCheck.is_int(v) else v
	return out


static func _customer_in(s: GameState, c, i: int, errs: Array[String]) -> void:
	var path := "customers[%d]" % i
	if typeof(c) != TYPE_DICTIONARY:
		errs.append("%s: not_object" % path)
		return
	var required := ["customer_id", "phase", "position", "route", "route_index", "reservation_ids", "patience_remaining_sec", "target_fixture_id", "checkout_remaining_sec"]
	var optional := ["target_sku_id", "queue_slot", "register_id", "retries", "walk_progress", "queue_since_sec", "outcome", "basket_size", "basket_wishes", "browse_remaining_sec", "visit"]
	var k_errs := JsonCheck.key_errors(c, required, optional, path)
	errs.append_array(k_errs)
	if not k_errs.is_empty():
		return
	if not JsonCheck.is_nonempty_string(c["customer_id"]) or not PHASE_IN.has(c["phase"]):
		errs.append("%s: invalid_id_or_phase" % path)
		return
	if typeof(c["position"]) != TYPE_DICTIONARY or typeof(c["route"]) != TYPE_ARRAY or typeof(c["reservation_ids"]) != TYPE_ARRAY:
		errs.append("%s: invalid_shape" % path)
		return
	var path_tiles: Array[Vector2i] = []
	for p in c["route"]:
		if typeof(p) != TYPE_DICTIONARY or not p.has("x") or not p.has("y") or not JsonCheck.is_int(p["x"]) or not JsonCheck.is_int(p["y"]):
			errs.append("%s.route: invalid" % path)
			return
		path_tiles.append(Vector2i(int(p["x"]), int(p["y"])))
	var pos = c["position"]
	if not pos.has("x") or not pos.has("y") or not JsonCheck.is_int(pos["x"]) or not JsonCheck.is_int(pos["y"]):
		errs.append("%s.position: invalid" % path)
		return
	if not JsonCheck.is_int(c["checkout_remaining_sec"]):
		errs.append("%s.checkout_remaining_sec: invalid" % path)
		return
	var phase: String = PHASE_IN[c["phase"]]
	var slot: int = int(c.get("queue_slot", -1))
	if phase == "QUEUE" and slot < 0:
		phase = "WAIT_QUEUE"
	var ids: Array[String] = []
	for id in c["reservation_ids"]:
		if not JsonCheck.is_nonempty_string(id):
			errs.append("%s.reservation_ids: invalid" % path)
			return
		ids.append(id)
	# Schema 1 has no basket keys: one item and no wishes (issue #128).
	var basket_size := 1
	if c.has("basket_size"):
		if not JsonCheck.is_int(c["basket_size"]) or int(c["basket_size"]) < BasketModel.MIN_SIZE or int(c["basket_size"]) > BasketModel.MAX_SIZE:
			errs.append("%s.basket_size: invalid" % path)
			return
		basket_size = int(c["basket_size"])
	var wishes: Array = []
	for w in c.get("basket_wishes", []):
		if typeof(w) != TYPE_DICTIONARY or not JsonCheck.is_nonempty_string(w.get("sku_id")) or not JsonCheck.is_nonempty_string(w.get("fixture_id")):
			errs.append("%s.basket_wishes: invalid" % path)
			return
		wishes.append({"sku_id": String(w["sku_id"]), "fixture_id": String(w["fixture_id"])})
	var visit := _visit_in(c.get("visit", {}), path, errs)
	if visit.is_empty():
		return
	s.customers.append({
		"customer_id": c["customer_id"], "phase": phase, "tile": Vector2i(int(pos["x"]), int(pos["y"])), "path": path_tiles,
		"progress": float(c.get("walk_progress", 0.0)), "fixture_id": "" if c["target_fixture_id"] == null else c["target_fixture_id"],
		"sku_id": "" if c.get("target_sku_id") == null else c["target_sku_id"],
		"reservation_ids": ids,
		"queue_slot": slot, "retries": int(c.get("retries", 0)), "queue_since": int(c.get("queue_since_sec", 0)),
		"checkout_left": int(c["checkout_remaining_sec"]), "register_id": c.get("register_id", ""), "outcome": c.get("outcome", ""),
		"browse_left": int(c.get("browse_remaining_sec", -1)),
		"basket_size": basket_size, "wishes": wishes,
		"purpose_id": visit["purpose_id"], "budget_yen": visit["budget_yen"], "wallet_yen": visit["wallet_yen"],
		"planned_yen": visit["planned_yen"], "impulse_count": visit["impulse_count"], "basket_log": visit["basket_log"],
		"seen_categories": visit["seen_categories"], "impulse_tried": visit["impulse_tried"],
		"segment_id": visit.get("segment_id", ""),
		"coupon_id": visit.get("coupon_id", ""),
	})


## The optional `visit` object (schema 3, #141); absent (schema 1/2) = no purpose. {} with an error when invalid.
static func _visit_in(v, path: String, errs: Array[String]) -> Dictionary:
	var out := {"purpose_id": "", "budget_yen": 0, "wallet_yen": 0, "planned_yen": 0, "impulse_count": 0,
		"basket_log": [], "seen_categories": [], "impulse_tried": []}
	if typeof(v) != TYPE_DICTIONARY:
		errs.append("%s.visit: not_object" % path)
		return {}
	if v.is_empty():
		return out
	var k_errs := JsonCheck.key_errors(v, ["purpose_id", "budget_yen", "wallet_yen", "planned_yen", "impulse_count", "basket_log", "seen_categories", "impulse_tried"], ["segment_id", "coupon_id"], path + ".visit")
	if not k_errs.is_empty():
		errs.append_array(k_errs)
		return {}
	for k in ["budget_yen", "wallet_yen", "planned_yen", "impulse_count"]:
		if not JsonCheck.is_int(v[k]) or int(v[k]) < 0:
			errs.append("%s.visit.%s: invalid" % [path, k])
			return {}
		out[k] = int(v[k])
	if typeof(v["purpose_id"]) != TYPE_STRING or typeof(v["basket_log"]) != TYPE_ARRAY or typeof(v["seen_categories"]) != TYPE_ARRAY or typeof(v["impulse_tried"]) != TYPE_ARRAY:
		errs.append("%s.visit: invalid_shape" % path)
		return {}
	out["purpose_id"] = String(v["purpose_id"])
	out["segment_id"] = String(v.get("segment_id", ""))
	out["coupon_id"] = String(v.get("coupon_id", ""))
	for e in v["basket_log"]:
		if typeof(e) != TYPE_DICTIONARY or not JsonCheck.is_nonempty_string(e.get("sku_id")) or not JsonCheck.is_int(e.get("price_yen")) \
				or not ["target", "impulse", "deal"].has(e.get("kind")) or not ["planned", "taken", "not_bought", "too_expensive", "stockout"].has(e.get("state")):
			errs.append("%s.visit.basket_log: invalid" % path)
			return {}
		out["basket_log"].append({"sku_id": String(e["sku_id"]), "price": int(e["price_yen"]), "kind": String(e["kind"]), "state": String(e["state"])})
	for k in ["seen_categories", "impulse_tried"]:
		for x in v[k]:
			if not JsonCheck.is_nonempty_string(x):
				errs.append("%s.visit.%s: invalid" % [path, k])
				return {}
			(out[k] as Array).append(String(x))
	return out


# ---------------------------------------------------------------- cross-reference invariants (12 §5)

## Semantic checks on a fully built state; returns [] when it is consistent.
static func semantic_errors(s: GameState) -> Array[String]:
	var errs: Array[String] = []
	if s.business_state == GameState.SETUP:
		if not s.customers.is_empty() or not s.reservations.is_empty():
			errs.append("SETUP: customers_or_reservations_present")
		if s.speed_setting != 0:
			errs.append("SETUP: speed_not_zero")
	var by_segment := {}
	var res_ids := {}
	var segs := {}
	for seg in s.inventory_segments:
		segs[seg["segment_id"]] = seg
		if int(seg["reserved_qty"]) > int(seg["physical_qty"]):
			errs.append("%s: reserved_exceeds_physical" % seg["segment_id"])
	for r in s.reservations:
		if res_ids.has(r["reservation_id"]):
			errs.append("%s: duplicate_reservation" % r["reservation_id"])
		res_ids[r["reservation_id"]] = true
		if not segs.has(r["segment_id"]):
			errs.append("%s: unknown_segment" % r["reservation_id"])
			continue
		by_segment[r["segment_id"]] = int(by_segment.get(r["segment_id"], 0)) + int(r["qty"])
	for id in segs:
		if int(segs[id]["reserved_qty"]) != int(by_segment.get(id, 0)):
			errs.append("%s: reserved_qty_mismatch" % id)
	var seen := {}
	for c in s.customers:
		if seen.has(c["customer_id"]):
			errs.append("%s: duplicate_customer" % c["customer_id"])
		seen[c["customer_id"]] = true
		for id in c["reservation_ids"]:
			if not res_ids.has(id):
				errs.append("%s: unknown_reservation" % c["customer_id"])
		if c["fixture_id"] != "" and not s.grid.instances.has(c["fixture_id"]):
			errs.append("%s: unknown_fixture" % c["customer_id"])
		if c["sku_id"] != "" and not s.products.has_sku(c["sku_id"]):
			errs.append("%s: unknown_sku" % c["customer_id"])
		var outside: bool = c["phase"] in ["APPROACH", "ENTER", "WALK_AWAY"]   # #142: on the pavement
		if not outside and not s.grid.in_bounds(c["tile"]):
			errs.append("%s: out_of_bounds" % c["customer_id"])
		elif outside and (absi(c["tile"].x) > s.grid.width + CustomerAI.OUTSIDE_MARGIN + 3 or absi(c["tile"].y) > s.grid.height + CustomerAI.OUTSIDE_MARGIN + 3):
			errs.append("%s: too_far_outside" % c["customer_id"])
	for r in s.reservations:
		if r["customer_id"] != "" and not seen.has(r["customer_id"]) and s.business_state != GameState.SETUP:
			errs.append("%s: reservation_without_customer" % r["reservation_id"])
	for sku_id in s.product_price_overrides:
		if not s.products.has_sku(sku_id):
			errs.append("product_price_overrides.%s: unknown_sku" % sku_id)
	# Daily charges are at-most-once per day and kind; ledger cash must be reproducible.
	var charges := {}
	for tx in s.ledger.transactions:
		if ["AD", "DAILY_FIXED", "ELECTRICITY", "WAGES"].has(tx["event_type"]):
			var key := "%s%d:%s" % [Ledger.store_of(String(tx["event_id"])), tx["day_index"], tx["event_type"]]   # per store (#146)
			if charges.has(key):
				errs.append("%s: charged_twice" % key)
			charges[key] = true
	var days := {}
	for rep in s.daily_reports:
		if days.has(rep["day_index"]):
			errs.append("daily_reports.%d: duplicate_day" % rep["day_index"])
		days[rep["day_index"]] = true
	return errs
