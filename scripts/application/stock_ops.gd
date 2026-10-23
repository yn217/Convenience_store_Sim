class_name StockOps
extends RefCounted
## ORDER_STOCK / RESTOCK rules (03 §C). Each function validates everything first and mutates
## only when it cannot fail, so a rejected command changes nothing. Returns
## {"ok": bool, "code": StringName, "key": StringName, "data": Dictionary, "event": String}.

const MAX_QTY := 9999


static func _fail(code: StringName, key: StringName) -> Dictionary:
	return {"ok": false, "code": code, "key": key, "data": {}, "event": ""}


static func _ok(event: String, data: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"OK", "key": &"", "data": data, "event": event}


## MVP: delivery is immediate. Cash is debited once and one backroom lot is created.
static func order(state: GameState, command_id: String, sku_id, qty) -> Dictionary:
	if typeof(sku_id) != TYPE_STRING or not state.products.has_sku(sku_id):
		return _fail(&"INVALID_OPERATION", &"sku_unknown")
	if typeof(qty) != TYPE_INT or qty < 1 or qty > MAX_QTY:
		return _fail(&"INVALID_OPERATION", &"qty_invalid")
	var sku := state.products.get_sku(sku_id)
	var cost: int = qty * int(sku["purchase_cost_yen"])
	var event := "%s:STOCK_PURCHASED" % command_id
	if not state.ledger.record("ORDER", event, -cost, state.day, state.time_sec, {"sku_id": sku_id, "qty": qty}):
		return _fail(&"INSUFFICIENT_CASH", &"not_enough_cash")
	state.next_lot_seq += 1
	state.next_segment_seq += 1
	var expires = sku["expires_after_seconds"]
	state.inventory_segments.append({
		"segment_id": "seg_%04d" % state.next_segment_seq,
		"lot_id": "lot_%04d" % state.next_lot_seq,
		"sku_id": sku_id,
		"unit_cost_yen": int(sku["purchase_cost_yen"]),
		"expires_at_sec": null if expires == null else state.time_sec + int(expires),
		"physical_qty": qty,
		"reserved_qty": 0,
		"location": {"kind": "BACKROOM"},
	})
	return _ok(event, {"cost_yen": cost})


## Backroom -> shelf slot, FEFO, all or nothing. Total stock is conserved: each moved unit
## either relocates a whole segment or splits it into a new segment with the same lot/cost/expiry.
static func restock(state: GameState, command_id: String, instance_id, slot_id, sku_id, qty) -> Dictionary:
	if typeof(instance_id) != TYPE_STRING or typeof(slot_id) != TYPE_STRING or typeof(sku_id) != TYPE_STRING or typeof(qty) != TYPE_INT:
		return _fail(&"INVALID_OPERATION", &"command_malformed")
	if qty < 1 or qty > MAX_QTY:
		return _fail(&"INVALID_OPERATION", &"qty_invalid")
	if not state.grid.instances.has(instance_id):
		return _fail(&"INVALID_OPERATION", &"unknown_instance")
	if not state.products.has_sku(sku_id):
		return _fail(&"INVALID_OPERATION", &"sku_unknown")
	var type_id: String = state.grid.instances[instance_id]["type_id"]
	var slot := {}
	for s in state.fixtures.get_type(type_id)["shelf_slots"]:
		if s["slot_id"] == slot_id:
			slot = s
	if slot.is_empty():
		return _fail(&"INVALID_OPERATION", &"unknown_slot")
	var sku := state.products.get_sku(sku_id)
	if not slot["allowed_categories"].has(sku["category"]):
		return _fail(&"INVALID_OPERATION", &"category_mismatch")
	var used := 0
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" and loc["fixture_id"] == instance_id and loc["slot_id"] == slot_id and int(seg["physical_qty"]) > 0:
			if seg["sku_id"] != sku_id:
				return _fail(&"INVALID_OPERATION", &"slot_other_sku")
			used += int(seg["physical_qty"]) * int(state.products.get_sku(sku_id)["slot_units"])
	if used + qty * int(sku["slot_units"]) > int(slot["capacity_units"]):
		return _fail(&"INVALID_OPERATION", &"capacity_exceeded")
	if state.backroom_available(sku_id) < qty:
		return _fail(&"INVALID_OPERATION", &"not_enough_stock")
	var sources: Array = []
	for seg in state.inventory_segments:
		if seg["sku_id"] == sku_id and seg["location"]["kind"] == "BACKROOM" and int(seg["physical_qty"]) > int(seg["reserved_qty"]):
			sources.append(seg)
	sources.sort_custom(_fefo_before)
	var target := {"kind": "FIXTURE", "fixture_id": instance_id, "slot_id": slot_id}
	var remaining: int = qty
	for seg in sources:
		if remaining == 0:
			break
		var take: int = mini(remaining, int(seg["physical_qty"]) - int(seg["reserved_qty"]))
		if take == int(seg["physical_qty"]):
			seg["location"] = target.duplicate()
		else:
			seg["physical_qty"] = int(seg["physical_qty"]) - take
			state.next_segment_seq += 1
			var part: Dictionary = seg.duplicate(true)
			part["segment_id"] = "seg_%04d" % state.next_segment_seq
			part["physical_qty"] = take
			part["reserved_qty"] = 0
			part["location"] = target.duplicate()
			state.inventory_segments.append(part)
		remaining -= take
	return _ok("%s:STOCK_MOVED" % command_id, {"moved_qty": qty})


## Earliest expiry first; no expiry last; segment id breaks ties.
static func _fefo_before(a: Dictionary, b: Dictionary) -> bool:
	var ea = a["expires_at_sec"]
	var eb = b["expires_at_sec"]
	if ea == null and eb == null:
		return a["segment_id"] < b["segment_id"]
	if ea == null:
		return false
	if eb == null:
		return true
	if ea != eb:
		return ea < eb
	return a["segment_id"] < b["segment_id"]
