class_name SalesIndex
extends RefCounted
## Per-day sums of this store's SALE rows, kept up to date incrementally: each call reads only the ledger rows added
## since the last one. The views ask for today and yesterday many times a second (rankings, the hourly chart, the
## per-fixture card, the HUD), and walking the day's rows for each of them cost tens of ms on a busy day.
## Rows are only ever appended to the ledger; a different ledger, a different store scope or fewer rows than seen
## (a load, a store switch) rebuilds from the start. Not saved: it is rebuilt from the ledger.
## Bucket per day: {pl (LedgerSummary sums of every row type), units, revenue, cogs, hours[24], fixture_units{}, fixture_money{fid: {revenue_yen, gross_profit_yen}},
## skus{sku: {qty, revenue_yen}}, shelves{fid: {qty, revenue_yen}}}; skus / shelves count product sales only (rows with
## a reservation): crane plays and lottery tickets are not products.

var _ledger: Ledger = null
var _scope := ""
var _cursor := 0
var _days := {}   # day index -> bucket
var kept_from := -1   # buckets before this day were dropped; ask a fresh index for them


## The bucket of `day_index` after reading any new rows ({} sums when that day sold nothing).
func day(ledger: Ledger, day_index: int) -> Dictionary:
	_catch_up(ledger)
	return _days.get(day_index, _empty())


## Drops the buckets of days before `keep_from` (the views only ask for today and yesterday).
func forget_before(keep_from: int) -> void:
	if keep_from <= kept_from:
		return
	kept_from = keep_from
	for d in _days.keys():
		if int(d) < keep_from:
			_days.erase(d)


func _catch_up(ledger: Ledger) -> void:
	var rows: Array = ledger.transactions
	if ledger != _ledger or ledger.scope != _scope or rows.size() < _cursor:
		_ledger = ledger
		_scope = ledger.scope
		_cursor = 0
		_days.clear()
		kept_from = -1
	for i in range(_cursor, rows.size()):
		var tx: Dictionary = rows[i]
		if not ledger.is_mine(tx):
			continue
		var d := int(tx["day_index"])
		if not _days.has(d):
			_days[d] = _empty()
		LedgerSummary.add_row(_days[d]["pl"], tx)   # the day's profit and loss, every row type
		if tx["event_type"] == "SALE":
			_add(tx)
	_cursor = rows.size()


func _add(tx: Dictionary) -> void:
	var d := int(tx["day_index"])
	if not _days.has(d):
		_days[d] = _empty()
	var b: Dictionary = _days[d]
	var det: Dictionary = tx["details"]
	var qty := int(det.get("qty", 1))
	var rev := int(tx["revenue_delta_yen"])
	var cogs := int(tx["cogs_delta_yen"])
	b["units"] += qty
	b["revenue"] += rev
	b["cogs"] += cogs
	var h := (int(tx["time_sec"]) % 86400) / 3600
	b["hours"][h] = int(b["hours"][h]) + rev
	var fid := String(det.get("fixture_id", ""))
	if fid != "":
		b["fixture_units"][fid] = int(b["fixture_units"].get(fid, 0)) + qty
		var m: Dictionary = b["fixture_money"].get(fid, {"revenue_yen": 0, "gross_profit_yen": 0})
		m["revenue_yen"] = int(m["revenue_yen"]) + rev
		m["gross_profit_yen"] = int(m["gross_profit_yen"]) + rev - cogs
		b["fixture_money"][fid] = m
	if not det.has("reservation_id"):
		return
	var sku := String(det.get("sku_id", ""))
	if sku != "":
		var s: Dictionary = b["skus"].get(sku, {"qty": 0, "revenue_yen": 0})
		s["qty"] = int(s["qty"]) + qty
		s["revenue_yen"] = int(s["revenue_yen"]) + rev
		b["skus"][sku] = s
		if fid != "":
			var sh: Dictionary = b["shelves"].get(fid, {"qty": 0, "revenue_yen": 0})
			sh["qty"] = int(sh["qty"]) + qty
			sh["revenue_yen"] = int(sh["revenue_yen"]) + rev
			b["shelves"][fid] = sh


static func _empty() -> Dictionary:
	var hours: Array = []
	hours.resize(24)
	hours.fill(0)
	return {"units": 0, "revenue": 0, "cogs": 0, "hours": hours, "fixture_units": {}, "fixture_money": {}, "skus": {}, "shelves": {}, "pl": LedgerSummary.empty()}
