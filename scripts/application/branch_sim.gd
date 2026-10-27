class_name BranchSim
extends RefCounted
## The stores of the company that are not on screen (issue #146): an hourly calculation instead of walking
## customers. No random draws, so the store on screen keeps exactly its own sequence.
##   - Every hour of an OPEN store: the visitors the store would expect in that hour (its location curve, base,
##     reputation, assortment, tier and campaigns; its nearby facilities) with the fraction carried to the next
##     hour; they are served only by a cashier (one per staff member up to the registers, each
##     3600 / checkout seconds per hour) — the rest are lost; each served visitor takes ITEMS_PER_VISITOR items,
##     chosen in proportion to the shelf's pull (largest accumulated share first) and sold from the shelves
##     (real SALE rows, FEFO, with their cost); expiry runs; staff refill shelves below half from the backroom.
##   - At midnight: the day's report and the next day's charges (fixed, electricity, wages, ads, campaigns) on the
##     store's own ledger scope, like the store on screen.

const ITEMS_PER_VISITOR := 1.6
const RESTOCK_SLOTS_PER_STAFF := 3


## Called after every step of the store on screen.
static func step(active: GameState) -> void:
	if active.branches.is_empty():
		return
	var scope := active.ledger.scope
	for b in active.branches:
		b.set_store_id(b.store_id)
		b.time_sec = active.time_sec
		if b.day != active.day:
			var prev: int = b.day
			SimulationRunner.roll_day(b, prev, active.day)
		if active.time_sec % 3600 == 0 and b.business_state == GameState.OPEN:
			hour(b, DemandModel.hour_of_day(active.time_sec - 1))
	active.ledger.scope = scope


## One hour of an off-screen OPEN store.
static func hour(b: GameState, h: int) -> void:
	InventoryService.sweep_expired(b)
	var steps := 3600.0 / GameClock.STEP_GAME_SECONDS
	var base := float(b.balance.get("base_potential_visitors_per_day", 100)) * StoreLocation.visitors_multiplier(b.location_id)
	var curve: Array = [] if b.location_id == "" else StoreLocation.hour_weights(b.location_id)
	var ad := Marketing.ad_factor(b, h, DemandModel.ad_multiplier(b.balance.get("advertising_tiers", []), b.applied_ad_tier_yen), 1.0)
	var expected := DemandModel.step_probability(h, base, ad, b.reputation, DemandGenerator.stocked_category_count(b), b.balance, 1.0, curve) * steps
	for fid in b.facilities:
		expected += NearbyFacility.step_probability(NearbyFacility.find(fid), h) * steps
	expected *= Market.visitor_factor(b, b.rivals, b.day)   # #129
	b.branch_carry += expected
	var visitors := int(floor(b.branch_carry))
	b.branch_carry -= visitors
	b.visit_stats["potential"] += visitors
	var registers := 0
	for inst in b.grid.instances.values():
		if AccessService.is_register(b.fixtures.get_type(inst["type_id"])) and inst.get("enabled", true):
			registers += 1
	var cashiers := mini(b.staff.size(), registers) if StaffAI.enabled(b.balance) else registers
	var capacity := int(floor(float(cashiers) * 3600.0 / float(BasketModel.checkout_seconds(b.balance, 2))))
	var served := mini(visitors, capacity)
	b.visit_stats["lost"] += visitors - served
	b.visit_stats["entered"] += served
	b.branch_items_carry += float(served) * ITEMS_PER_VISITOR
	var items := int(floor(b.branch_items_carry))
	b.branch_items_carry -= items
	var sold := 0
	for k in items:
		var sku := _next_sku(b)
		if sku == "":
			break
		var res_id := "bres_%d_%d" % [b.time_sec, k]
		var res := InventoryService.reserve(b, res_id, "", sku, 600, "")
		if res.is_empty():
			continue
		if bool(InventoryService.complete_sale(b, "sale:%s" % res_id, res_id, "bsale_%d" % b.time_sec)["ok"]):
			sold += 1
		else:
			InventoryService.release_reservation(b, res_id)
	b.visit_stats["purchased"] += mini(served, sold)
	if StaffAI.enabled(b.balance) and not b.staff.is_empty():
		_restock(b, b.staff.size() * RESTOCK_SLOTS_PER_STAFF)


## The next item to sell: every SKU on the shelves gains its pull, the largest total is taken and pays the sum.
static func _next_sku(b: GameState) -> String:
	var avail := {}
	for seg in b.inventory_segments:
		if seg["location"]["kind"] == "FIXTURE" and int(seg["physical_qty"]) - int(seg["reserved_qty"]) > 0 and b.grid.instances.has(seg["location"]["fixture_id"]):
			avail[seg["sku_id"]] = true
	if avail.is_empty():
		return ""
	var ids := avail.keys()
	ids.sort()
	var total := 0.0
	var best := ""
	for id in ids:
		var sku := b.products.get_sku(id)
		var w := DemandModel.category_preference(sku["category"], b.balance) * StoreLocation.category_multiplier(b.location_id, sku["category"]) * float(sku["demand_weight"]) * Marketing.category_multiplier(b, sku["category"])
		b.branch_sku_acc[id] = float(b.branch_sku_acc.get(id, 0.0)) + w
		total += w
		if best == "" or float(b.branch_sku_acc[id]) > float(b.branch_sku_acc[best]):
			best = id
	b.branch_sku_acc[best] = float(b.branch_sku_acc[best]) - total
	return best


## Staff refill up to `slots` shelf slots below half full from the backroom.
static func _restock(b: GameState, slots: int) -> void:
	var ids := b.grid.instances.keys()
	ids.sort()
	var n := 0
	for id in ids:
		var def := b.fixtures.get_type(b.grid.instances[id]["type_id"])
		for slot in def["shelf_slots"]:
			if n >= slots:
				return
			var sku := StaffAI._slot_sku(b, id, slot)
			if sku == "" or b.backroom_available(sku) <= 0:
				continue
			var units := maxi(int(b.products.get_sku(sku)["slot_units"]), 1)
			var cap := int(slot["capacity_units"]) / units
			var need := StaffAI._slot_need(b, id, slot, sku)
			if float(cap - need) / float(maxi(cap, 1)) >= 0.5:
				continue
			var qty := mini(need, b.backroom_available(sku))
			if qty > 0 and bool(StockOps.restock(b, "brs_%d_%d" % [b.time_sec, n], id, slot["slot_id"], sku, qty).get("ok", false)):
				n += 1
