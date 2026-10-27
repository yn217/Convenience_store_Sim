class_name GameState
extends RefCounted
## Mutable runtime state. Only GameCommands / SimulationRunner write to it;
## presenters receive snapshot() copies (01 §2, §6).

const SCHEMA_VERSION := 1
const SETUP := &"SETUP"
const OPEN := &"OPEN"
const CLOSING := &"CLOSING"
const PAYMENT_BLOCKED := &"PAYMENT_BLOCKED"
const SPEED_OPTIONS: Array[int] = [0, 1, 2, 4]
## Default door: two tiles on the south wall (y = 11), the long near edge that faces the default camera. Saves carry
## their own entrance_tiles, so older saves keep the west door they were made with (00_BASELINE §2.1).
const ENTRANCE_TILES: Array[Vector2i] = [Vector2i(8, 11), Vector2i(9, 11)]

var revision: int = 0
var time_sec: int = 0
var day: int = 0
var business_state: StringName = SETUP
var speed_setting: int = 0
var last_nonzero_speed: int = 1
var applied_command_ids: Array[String] = []
var rng_states: Dictionary = {}
var reputation: int = 0
var fixtures := FixtureCatalog.new()
var products := ProductCatalog.new()
var grid: StoreGrid
var ledger := Ledger.new()
var layout_history := LayoutHistory.new()
## Stock rows (see StockSegment) and active customer reservations; filled by #11/#17.
var inventory_segments: Array[Dictionary] = []
var reservations: Array[Dictionary] = []
var next_fixture_seq: int = 0
var next_lot_seq: int = 0
var next_customer_seq: int = 0
## Balance config the simulation reads (demand base, ad tiers, customer cap).
var balance: Dictionary = {}
## Advertising tier (yen/day) in force today; the ad system (M4-01) changes it at day start.
var applied_ad_tier_yen: int = 0
## Budget chosen for the next game day; it is charged and applied when that day is first charged.
var next_day_ad_yen: int = 0
## Costs recognised but not paid because cash ran out (shown separately from cash).
var unpaid_cost_yen: int = 0
var construction_days: int = 0   # #145: days of expansion work still to pass before the store opens again
## Today's visitor counters, kept apart (03 §G): wished-to-visit / actually entered / turned away.
var visit_stats := {"potential": 0, "entered": 0, "lost": 0, "purchased": 0}
var mood_today := {"sum": 0, "n": 0}   # #141: moods of the customers who left today (not saved: a reload counts on)
var staff: Array = []          # #143: store staff (StaffAI)
var next_staff_seq := 0
var staff_candidates: Array = []        # #144: today's hiring candidates (StaffMarket)
var promotions: Array = []      # #137: running and finished promotions (Promotions)
var next_promotion_seq := 0
var promo_stats: Dictionary = {}
var campaigns: Array = []          # #136: media advertising campaigns (Marketing)
var next_campaign_seq := 0
var coupons: Array = []            # #137: outstanding next-visit coupons (Promotions.issue_coupon)
var next_coupon_seq := 0  # promotion id -> {units, discount_yen}
var facilities: Array = []             # #149: nearby facility ids (NearbyFacility), chosen before the first opening
var facility_visits: Dictionary = {}   # facility id -> visitors it sent today
var visitors_by_hour: Array = []          # #150: potential visitors per hour today (24) and yesterday, for the map
var visitors_by_hour_yesterday: Array = []
var map_id := ""                       # #150: the area map and the store's site on it ("" = chosen without the map)
var plot_id := ""
var store_id := ""                      # #146: "" for the first store, "s2" ... (the ledger scope and id prefixes)
var store_name := ""                    # #146: shown in the store list ("" = 1号店)
var branches: Array = []                # #146: the company's other stores (only on the store on screen)
var rivals: Array = []                  # #129: rival stores on the map (Market), the company's
var rivals_enabled := true
var eat_in_total := 0                  # #134: customers who sat down to eat
var lotteries: Array = []              # #138: prize draw sets bought and their tickets (Lottery)
var capsule_stats: Dictionary = {}     # #139: sku_id -> {turns, rare} of the capsule machines (CapsuleToys)
var market_conditions: Array = []      # #129 phase 2: local conditions (Market), the company's
var branch_carry := 0.0                 # #146 BranchSim: fractions of visitors and items carried between hours
var branch_items_carry := 0.0
var branch_sku_acc: Dictionary = {}     # #146 BranchSim: accumulated pull per SKU
var location_id := ""                   # #148: station / school / office / residential; "" = the standard store
var staff_metrics: Dictionary = {}      # #144: today's staffing figures (StaffMarket.record_step)
var staff_metrics_yesterday: Dictionary = {}
## Inputs of the daily reputation update: customers who gave up in the queue / found nothing to buy.
var rate_stats := {"abandoned": 0, "stockouts": 0}
## Customers in the store (filled by M3-02) and arrivals waiting to be spawned as customers.
var customers: Array[Dictionary] = []
var arrival_queue: Array[Dictionary] = []
## Closed days, oldest first (see DailyReport). Never rewritten once appended.
var daily_reports: Array[Dictionary] = []
## Milestone definitions (data/progression) and the transient pieces of ProgressionService:
## achievements waiting to be announced, and incremental ledger totals (rebuilt after a load).
var milestones: Array[Dictionary] = []
var progression_events: Array[Dictionary] = []
var progression_totals := {"scanned": 0, "sales": 0, "revenue": 0, "order_qty": 0, "sales_by_day": {}}
## Saved verbatim until the event director / progression systems (M5-07, M4-06) own them.
## Event master data (data/events); empty = the director is off. Loaded by AppRoot, never saved.
var gameplay_events: Array[Dictionary] = []
var gameplay_event_state: Dictionary = {
	"last_selected_day": -1, "selection_event_id": null, "selected_event_id": null, "event_start_sec": null,
	"event_end_sec": null, "started": false, "ended": false, "shown_notice_ids": [],
}
var progression_state: Dictionary = {
	"tutorial_skipped": false, "tutorial_step_index": 0, "completed_milestone_ids": [],
	"completed_daily_challenge_ids": [], "active_daily_challenge_day": -1, "active_daily_challenge_id": null,
	"challenge_stock_qualified": false, "dismissed_story_cue_ids": [],
}
var next_segment_seq: int = 0
## Player sell prices that differ from the SKU default {sku_id: yen}. Never touches lot costs
## or already snapshotted reservations/ledger rows.
var product_price_overrides: Dictionary = {}

var store_width: int:
	get: return grid.width
var store_height: int:
	get: return grid.height
var entrance_tiles: Array[Vector2i]:
	get: return grid.entrance_tiles
var cash_yen: int:
	get: return ledger.cash_yen


static func from_balance(balance: Dictionary, seeds: Dictionary, fixture_catalog: FixtureCatalog = null, product_catalog: ProductCatalog = null) -> GameState:
	var s := GameState.new()
	if fixture_catalog != null:
		s.fixtures = fixture_catalog
	if product_catalog != null:
		s.products = product_catalog
	s.grid = StoreGrid.create("store_001", int(balance["store_width_tiles"]), int(balance["store_height_tiles"]), ENTRANCE_TILES.duplicate())
	s.ledger.cash_yen = int(balance["starting_cash_yen"])
	s.reputation = int(balance["starting_reputation"])
	s.rng_states = seeds.duplicate()
	if not s.rng_states.has("events"):
		s.rng_states["events"] = 345678   # separate stream for the event director (09 §1)
	if not s.rng_states.has("visits"):
		s.rng_states["visits"] = 246813   # budget and wallet of each visit (#141)
	if not s.rng_states.has("impulse"):
		s.rng_states["impulse"] = 135792   # impulse pick-ups on the way (#141)
	if not s.rng_states.has("staff"):
		s.rng_states["staff"] = 97531   # hiring candidates (#144)
	s.balance = balance.duplicate(true)
	s.next_day_ad_yen = int(balance.get("starting_ad_budget_yen_per_day", 0))
	if StaffAI.enabled(s.balance):
		for entry in s.balance.get("starting_staff", []):
			s.staff.append(StaffAI.make(s, entry, s.grid.entrance_tiles[0]))
		s.staff_metrics = StaffMarket.empty_metrics()
		StaffMarket.draw_candidates(s)
	return s


## Closes `day_index` exactly once: the report is built from that day's ledger rows and the
## per-day visitor counters restart. A day that already has a report is left untouched.
## Facts for the presentation (14 §5): EventEnvelope {id, tick, type, payload}. Transient: never saved,
## never read by the simulation; losing or ignoring them changes no money, stock or customer.
const EVENT_LOG_CAP := 512
var event_log: Array[Dictionary] = []
var _next_event_seq: int = 0


func emit_event(type: String, payload: Dictionary, explicit_id: String = "") -> void:
	_next_event_seq += 1
	event_log.append({"id": explicit_id if explicit_id != "" else "ev_%06d" % _next_event_seq, "tick": time_sec, "type": type, "payload": payload})
	if event_log.size() > EVENT_LOG_CAP:
		event_log.pop_front()


## Events since the last call; the cue bridge turns each one into at most one cue request.
func take_events() -> Array[Dictionary]:
	var out := event_log.duplicate()
	event_log.clear()
	return out


func close_day_once(day_index: int) -> bool:
	for r in daily_reports:
		if r["day_index"] == day_index:
			return false
	daily_reports.append(DailyReport.build(day_index, ledger, visit_stats, reputation, ledger.cash_yen, mood_today))
	mood_today = {"sum": 0, "n": 0}
	reputation = ReputationModel.next_reputation(reputation, visit_stats, rate_stats, balance)
	visit_stats = {"potential": 0, "entered": 0, "lost": 0, "purchased": 0}
	rate_stats = {"abandoned": 0, "stockouts": 0}
	if StaffAI.enabled(balance):
		staff_metrics_yesterday = staff_metrics
		staff_metrics = StaffMarket.empty_metrics()
	emit_event("DAILY_CLOSED", {"day_index": day_index})
	return true


## Makes this state store `id` of the company: its ledger rows and staff ids carry the id (#146).
func set_store_id(id: String) -> void:
	store_id = id
	ledger.scope = "" if id == "" else id + "/"


## Revenue and gross profit of the current day for the HUD. Walks the ledger from the end and
## stops at the first earlier day, so it stays cheap while the ledger grows.
func today_summary() -> Dictionary:
	var revenue := 0
	var cogs := 0
	for i in range(ledger.transactions.size() - 1, -1, -1):
		var tx: Dictionary = ledger.transactions[i]
		if int(tx["day_index"]) < day:
			break
		if tx["event_type"] == "SALE" and ledger.is_mine(tx):
			revenue += int(tx["revenue_delta_yen"])
			cogs += int(tx["cogs_delta_yen"])
	return {"revenue_yen": revenue, "gross_profit_yen": revenue - cogs}


## Items sold today (sum of SALE qty; a basket of 3 items is 3). Same backwards walk as today_summary().
func units_sold_today() -> int:
	var units := 0
	for i in range(ledger.transactions.size() - 1, -1, -1):
		var tx: Dictionary = ledger.transactions[i]
		if int(tx["day_index"]) < day:
			break
		if tx["event_type"] == "SALE" and ledger.is_mine(tx):
			units += int(tx["details"].get("qty", 1))
	return units


## Units sold today per fixture id (SALE rows carry the fixture they were taken from).
func fixture_sales_today() -> Dictionary:
	var out := {}
	for i in range(ledger.transactions.size() - 1, -1, -1):
		var tx: Dictionary = ledger.transactions[i]
		if int(tx["day_index"]) < day:
			break
		if tx["event_type"] == "SALE" and tx["details"].get("fixture_id", "") != "" and ledger.is_mine(tx):
			out[tx["details"]["fixture_id"]] = int(out.get(tx["details"]["fixture_id"], 0)) + int(tx["details"].get("qty", 1))
	return out


## Revenue and gross profit per fixture id today (the selected-fixture card). Same walk as above.
func fixture_money_today() -> Dictionary:
	var out := {}
	for i in range(ledger.transactions.size() - 1, -1, -1):
		var tx: Dictionary = ledger.transactions[i]
		if int(tx["day_index"]) < day:
			break
		if tx["event_type"] == "SALE" and tx["details"].get("fixture_id", "") != "" and ledger.is_mine(tx):
			var fid: String = tx["details"]["fixture_id"]
			var m: Dictionary = out.get(fid, {"revenue_yen": 0, "gross_profit_yen": 0})
			m["revenue_yen"] = int(m["revenue_yen"]) + int(tx["revenue_delta_yen"])
			m["gross_profit_yen"] = int(m["gross_profit_yen"]) + int(tx["revenue_delta_yen"]) - int(tx["cogs_delta_yen"])
			out[fid] = m
	return out


## Achievements since the last call; the UI announces each one exactly once.
func take_progression_events() -> Array[Dictionary]:
	var out := progression_events.duplicate()
	progression_events.clear()
	return out


func active_customer_count() -> int:
	return customers.size()


## The price the player set (or the default): what SET_PRICE edits and the price shown as the list price.
func list_price(sku_id: String) -> int:
	if product_price_overrides.has(sku_id):
		return int(product_price_overrides[sku_id])
	return int(products.get_sku(sku_id).get("default_sell_price_yen", 0))


## The price customers pay now: the list price, or a running promotion's sale price (#137).
func sell_price(sku_id: String) -> int:
	var list := list_price(sku_id)
	if promotions.is_empty():
		return list
	return int(Promotions.price_now(self, sku_id, list)["price"])


## Units of `sku_id` in the backroom that no reservation holds.
func backroom_available(sku_id: String) -> int:
	var n := 0
	for seg in inventory_segments:
		if seg["sku_id"] == sku_id and seg["location"]["kind"] == "BACKROOM":
			n += int(seg["physical_qty"]) - int(seg["reserved_qty"])
	return n


func snapshot() -> Dictionary:
	var stocked := DemandGenerator.stocked_categories(self)   # once: the achievements list needs the count too
	var ids := grid.instances.keys()
	ids.sort()
	var placed: Array = []
	for id in ids:
		placed.append(grid.instances[id].duplicate())
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"time_sec": time_sec,
		"day": day,
		"business_state": String(business_state),
		"speed_setting": speed_setting,
		"store_width": grid.width,
		"store_height": grid.height,
		"entrance_tiles": grid.entrance_tiles.duplicate(),
		"fixtures": placed,
		"product_price_overrides": product_price_overrides.duplicate(),
		"backroom_stock": _backroom_stock(),
		"shelf_skus": _shelf_skus(),
		"shelf_stock": ShelfDisplay.stock_by_slot(inventory_segments),
		"can_undo": layout_history.can_undo(),
		"can_redo": layout_history.can_redo(),
		"cash_yen": ledger.cash_yen,
		"reputation": reputation,
		"rng_states": rng_states.duplicate(),
		"next_day_ad_yen": next_day_ad_yen,
		"applied_ad_tier_yen": applied_ad_tier_yen,
		"unpaid_cost_yen": unpaid_cost_yen,
		"daily_reports": daily_reports.duplicate(true),
		"today": today_summary(),
		"units_sold_today": units_sold_today(),
		"progression": progression_state.duplicate(true),
		"story_cue": AssistantService.current(self),
		"milestone_progress": ProgressionService.milestone_progress(self, stocked.size()),
		"opening": BusinessService.opening_report(self) if business_state == SETUP else {},
		"visit_stats": visit_stats.duplicate(),
		"rate_stats": rate_stats.duplicate(),
		"customers": _customer_views() + _staff_views(),
		"closed_registers": closed_registers(),
		"staff_count": staff.size(), "staff_cap": StaffAI.capacity(self) if StaffAI.enabled(balance) else 0,
		"staff_candidates": _candidate_views(), "staffing": _staffing_view(),
		"location_id": location_id, "location_name": StoreLocation.display_name(location_id), "location_locked": location_locked(),
		"promotions": _promotion_views(), "lotteries": Lottery.views(self), "lottery_selling": not Lottery.selling(self).is_empty(),
		"stores": Company.views(self), "store_id": store_id,
		"rivals": Market.views(self, rivals, day), "conditions": Market.condition_views(market_conditions, day), "rivals_enabled": rivals_enabled, "capsule_stats": capsule_stats.duplicate(true), "rival_factor": Market.visitor_factor(self, rivals, day),
		"company_totals": Company.totals(self, int(daily_reports.back()["day_index"]) if not daily_reports.is_empty() else -1),
		"marketing": Marketing.views(self),
		"map_id": map_id, "plot_id": plot_id,
		"visitors_by_hour": visitors_by_hour.duplicate(), "visitors_by_hour_yesterday": visitors_by_hour_yesterday.duplicate(),
		"facilities": facilities.duplicate(), "facility_visits": facility_visits.duplicate(), "max_facilities": NearbyFacility.max_count(),
		"store_size_id": String(StoreSize.of_grid(balance, grid).get("size_id", "")), "store_sizes": StoreSize.all(balance),
		"next_store_size": StoreSize.next(balance, grid), "construction_days": construction_days,
		"checkout_duration_sec": BasketModel.checkout_seconds(balance, roundi(BasketModel.mean_size(balance))),   # the average basket, for the queue estimate
		"walk_tiles_per_game_second": float(balance.get("customer_walk_tiles_per_game_second", 0.0)),
		"passersby_per_day": int(balance.get("passersby_per_day", 0)) if bool(balance.get("outdoor_approach", false)) else 0,   # #142, presentation only   # the figures walk at the simulation's pace (#117 v2)
		"fixture_sales": fixture_sales_today(),
		"fixture_money": fixture_money_today(),
		"gameplay_event": EventService.view(self),
		"stocked_categories": stocked,
	}


func _backroom_stock() -> Dictionary:
	var out := {}
	for seg in inventory_segments:
		if seg["location"]["kind"] == "BACKROOM":
			out[seg["sku_id"]] = int(out.get(seg["sku_id"], 0)) + int(seg["physical_qty"])
	return out


## {fixture_id: {slot_id: sku_id}} for slots that currently hold stock.
func _shelf_skus() -> Dictionary:
	var out := {}
	for seg in inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and int(seg["physical_qty"]) > 0:
			if not out.has(loc["fixture_id"]):
				out[loc["fixture_id"]] = {}
			out[loc["fixture_id"]][loc["slot_id"]] = seg["sku_id"]
	return out


func _log_view(log: Array) -> Array:
	var out: Array = []
	for e in log:
		var sku := products.get_sku(e["sku_id"]) if products != null else {}
		out.append({"sku_id": e["sku_id"], "name": sku.get("display_name", e["sku_id"]), "category": sku.get("category", ""),
			"price": int(e["price"]), "kind": e["kind"], "state": e["state"]})
	return out


## Swaps in a resized grid (StoreSize.resized, #145): staff move with the rows, the layout history ends.
func apply_resized(res: Dictionary) -> void:
	grid = res["grid"]
	var dy := int(res["dy"])
	for s in staff:
		var t: Vector2i = s["tile"]
		s["tile"] = Vector2i(clampi(t.x, 0, grid.width - 1), clampi(t.y + dy, 0, grid.height - 1))
		s["path"] = [] as Array[Vector2i]
		s["progress"] = 0.0
		s["phase"] = "IDLE"
		s["task"] = {}
		s["carry"] = 0
	layout_history.clear()
	revision += 1


## One potential visitor in the current hour (DemandGenerator; #150 actual-vs-forecast).
func count_visitor_hour() -> void:
	if visitors_by_hour.size() != 24:
		visitors_by_hour.resize(24)
		visitors_by_hour.fill(0)
	var h := DemandModel.hour_of_day(time_sec)
	visitors_by_hour[h] = int(visitors_by_hour[h]) + 1


## Promotions for the 販促 card (#137): every definition with its running instance (if any) and results.
func _promotion_views() -> Array:
	var out: Array = []
	for d in Promotions.data()["promotions"]:
		var v: Dictionary = d.duplicate(true)
		v["running"] = {}
		for p in Promotions.running(self):
			if p["def_id"] == d["def_id"]:
				v["running"] = p.duplicate()
				v["running"]["days_left"] = int(p["end_day"]) - day + 1
				v["running"]["stats"] = promo_stats.get(p["promotion_id"], {}).duplicate()
		out.append(v)
	return out


## A customer leaving the store with this mood (#141).
func note_mood(mood: int) -> void:
	mood_today["sum"] = int(mood_today["sum"]) + mood
	mood_today["n"] = int(mood_today["n"]) + 1


## The location can be chosen until the store first opens (#148: no free move after it is built and running).
func location_locked() -> bool:
	return business_state != SETUP or time_sec > 0


func _candidate_views() -> Array:
	var out: Array = []
	for c in staff_candidates:
		var v: Dictionary = c.duplicate(true)
		v["label"] = StaffMarket.label(c["archetype"])
		v["daily_wage_yen"] = StaffAI.daily_wage(balance, c)
		out.append(v)
	return out


## The 店員 tab's figures (#144): line by hour today and yesterday, people lost to the line, utilisation, advice.
## Registers with nobody at the till while the store is trading (#143 / #113): their sign reads 休止中. Empty in
## SETUP and without the staff model (every register is open then).
func closed_registers() -> Array:
	var out: Array = []
	if not StaffAI.enabled(balance) or business_state == SETUP:
		return out
	var ids := grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = grid.instances[id]
		if not AccessService.is_register(fixtures.get_type(inst["type_id"])) or not inst.get("enabled", true):
			continue
		var cell := StaffAI.cashier_cell_cached(self, id)
		if not staff.any(func(s): return s["phase"] == "REGISTER" and s["tile"] == cell):
			out.append(id)
	return out


func _staffing_view() -> Dictionary:
	if not StaffAI.enabled(balance):
		return {}
	var util := {}
	for s in staff:
		util[s["staff_id"]] = StaffMarket.utilisation(staff_metrics, s["staff_id"])
	return {
		"line_today": StaffMarket.line_by_hour(staff_metrics), "line_yesterday": StaffMarket.line_by_hour(staff_metrics_yesterday),
		"balked_today": (staff_metrics.get("balked", []) as Array).duplicate(), "abandoned_today": (staff_metrics.get("abandoned", []) as Array).duplicate(),
		"utilisation": util, "advice": StaffMarket.advice(self), "wages_per_day": BusinessService.wages(self),
	}


## Staff drawn like customers (the presenter animates any id; "staff_" ids wear the clerk look, #143).
func _staff_views() -> Array:
	var out: Array = []
	for s in staff:
		var path: Array = s["path"]
		out.append({
			"customer_id": s["staff_id"], "staff": true, "name": s["name"], "archetype": s["archetype"], "skills": s["skills"].duplicate(),
			"fatigue": float(s["fatigue"]), "phase": s["phase"], "tile": s["tile"], "path": path.duplicate(),
			"next": path[0] if not path.is_empty() else s["tile"], "progress": float(s["progress"]) if not path.is_empty() else 0.0,
			"trail": (s["trail"] as Array).duplicate(), "moved": int(s["moved"]), "carry": int(s["carry"]),
			"task_fixture": String((s["task"] as Dictionary).get("fixture_id", "")), "task_sku": String((s["task"] as Dictionary).get("sku_id", "")),
			"daily_wage_yen": StaffAI.daily_wage(balance, s),
			"fixture_id": String((s["task"] as Dictionary).get("fixture_id", "")), "sku_id": "", "register_id": "", "queue_slot": -1, "outcome": "",
		})
	return out


func _customer_views() -> Array:
	var out: Array = []
	for c in customers:
		var path: Array = c.get("path", [])
		out.append({
			"customer_id": c["customer_id"], "tile": c["tile"], "phase": c["phase"],
			"next": path[0] if not path.is_empty() else c["tile"], "progress": float(c.get("progress", 0.0)) if not path.is_empty() else 0.0,
			"path": path.duplicate(), "trail": c.get("trail", []).duplicate(), "moved": int(c.get("moved", 0)),
			"fixture_id": c.get("fixture_id", ""),
			# Read-only copies for the presentation (what the customer is doing now); never read back by the simulation.
			"sku_id": c.get("sku_id", ""), "reserved": not (c.get("reservation_ids", []) as Array).is_empty(),
				"basket_size": int(c.get("basket_size", 1)), "items_reserved": (c.get("reservation_ids", []) as Array).size(),
			"register_id": c.get("register_id", ""), "queue_slot": int(c.get("queue_slot", -1)),
			"checkout_left": int(c.get("checkout_left", 0)),
			"browse_left": int(c.get("browse_left", -1)), "outcome": String(c.get("outcome", "")),
			# #141: purpose, money and the basket log (names and prices for the customer panel).
			"purpose_id": String(c.get("purpose_id", "")), "purpose_name": VisitPurpose.display_name(balance, String(c.get("purpose_id", ""))),
			"segment_name": NearbyFacility.segment_name(String(c.get("segment_id", ""))),   # #149
			"budget_yen": int(c.get("budget_yen", 0)), "wallet_yen": int(c.get("wallet_yen", 0)), "planned_yen": int(c.get("planned_yen", 0)),
			"impulse_count": int(c.get("impulse_count", 0)), "basket_log": _log_view(c.get("basket_log", [])),
			"mood": CustomerMood.of(c, time_sec),   # #141
			"target_tile": path[path.size() - 1] if not path.is_empty() else c["tile"],
		})
	return out
