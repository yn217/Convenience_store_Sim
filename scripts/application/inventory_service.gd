class_name InventoryService
extends RefCounted
## Stock lifecycle after the order/restock commands (03 §C/§E): expiry sweep, FEFO selection,
## reservation and the atomic checkout. Customers (M3) will call reserve()/complete_sale();
## this issue owns the rules, not the callers. Every function validates first and mutates
## only when it cannot fail.


## Expired = `time >= expires_at` (03 §C). Segments without an expiry never expire.
static func is_expired(seg: Dictionary, now_sec: int) -> bool:
	var e = seg["expires_at_sec"]
	return e != null and now_sec >= int(e)


## Step 2 of the tick (03 §B): release reservations on expired segments, then discard the whole
## remaining quantity and book `physical_qty * unit_cost_yen` as wastage exactly once. Cash and
## COGS do not move. Returns the wastage event ids booked.
static func sweep_expired(state: GameState) -> Array[String]:
	var booked: Array[String] = []
	var expired: Array[Dictionary] = []
	for seg in state.inventory_segments:
		if is_expired(seg, state.time_sec):
			expired.append(seg)
	expired.sort_custom(func(a, b): return a["segment_id"] < b["segment_id"])
	for seg in expired:
		var kept: Array[Dictionary] = []
		for res in state.reservations:
			if res["segment_id"] != seg["segment_id"]:
				kept.append(res)
		state.reservations = kept
		seg["reserved_qty"] = 0
		var qty := int(seg["physical_qty"])
		var cost := qty * int(seg["unit_cost_yen"])
		var event_id := "wastage:%s" % seg["segment_id"]
		if qty > 0:
			state.ledger.record("WASTAGE", event_id, 0, state.day, state.time_sec,
				{"segment_id": seg["segment_id"], "lot_id": seg["lot_id"], "sku_id": seg["sku_id"], "qty": qty},
				{"expense": cost})
			booked.append(event_id)
		seg["physical_qty"] = 0
	var alive: Array[Dictionary] = []
	for seg in state.inventory_segments:
		if int(seg["physical_qty"]) > 0 or int(seg["reserved_qty"]) > 0:
			alive.append(seg)
	state.inventory_segments = alive
	return booked


## The shelf segment a customer should take from: earliest expiry first (no expiry last), then
## segment id; expired or fully reserved segments are skipped. `fixture_id` limits the search.
static func pick_sale_segment(state: GameState, sku_id: String, fixture_id: String = "") -> Dictionary:
	var best := {}
	for seg in state.inventory_segments:
		var loc: Dictionary = seg["location"]
		if seg["sku_id"] != sku_id or loc["kind"] != "FIXTURE":
			continue
		if fixture_id != "" and loc["fixture_id"] != fixture_id:
			continue
		if is_expired(seg, state.time_sec) or int(seg["physical_qty"]) - int(seg["reserved_qty"]) < 1:
			continue
		if best.is_empty() or StockOps._fefo_before(seg, best):
			best = seg
	return best


## Reserves one unit with the price and cost snapshots taken now. Returns {} when nothing can be
## reserved (no stock, all reserved, expired) or the id is already used.
static func reserve(state: GameState, reservation_id: String, customer_id: String, sku_id: String, hold_sec: int, fixture_id: String = "") -> Dictionary:
	for r in state.reservations:
		if r["reservation_id"] == reservation_id:
			return {}
	var price := state.sell_price(sku_id)
	if price < 1:
		return {}
	var seg := pick_sale_segment(state, sku_id, fixture_id)
	if seg.is_empty():
		return {}
	seg["reserved_qty"] = int(seg["reserved_qty"]) + 1
	var res := {
		"reservation_id": reservation_id, "customer_id": customer_id, "segment_id": seg["segment_id"], "qty": 1,
		"sell_unit_yen_snapshot": price, "cost_unit_yen_snapshot": int(seg["unit_cost_yen"]),
		"reservation_expires_at_sec": state.time_sec + hold_sec,
	}
	state.reservations.append(res)
	return res


## Atomic checkout (03 §E): one transaction id is applied once; an expired segment sells nothing.
## Returns {"ok": bool, "reason": String}.
static func complete_sale(state: GameState, transaction_id: String, reservation_id: String) -> Dictionary:
	if state.ledger.has_event(transaction_id):
		return {"ok": false, "reason": "duplicate_transaction"}
	var index := -1
	for i in state.reservations.size():
		if state.reservations[i]["reservation_id"] == reservation_id:
			index = i
	if index < 0:
		return {"ok": false, "reason": "unknown_reservation"}
	var res: Dictionary = state.reservations[index]
	var seg := {}
	for s in state.inventory_segments:
		if s["segment_id"] == res["segment_id"]:
			seg = s
	if seg.is_empty() or is_expired(seg, state.time_sec):
		return {"ok": false, "reason": "expired_or_missing"}
	var qty := int(res["qty"])
	var revenue := int(res["sell_unit_yen_snapshot"]) * qty
	var cogs := int(res["cost_unit_yen_snapshot"]) * qty
	if not state.ledger.record("SALE", transaction_id, revenue, state.day, state.time_sec,
			{"reservation_id": reservation_id, "sku_id": seg["sku_id"], "qty": qty}, {"revenue": revenue, "cogs": cogs}):
		return {"ok": false, "reason": "ledger_rejected"}
	seg["physical_qty"] = int(seg["physical_qty"]) - qty
	seg["reserved_qty"] = int(seg["reserved_qty"]) - qty
	state.reservations.remove_at(index)
	return {"ok": true, "reason": ""}
