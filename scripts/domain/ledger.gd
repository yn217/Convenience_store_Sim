class_name Ledger
extends RefCounted
## Cash ledger (savegame.schema.json `economy`). History is append-only: an Undo is a
## REVERSAL event, never a deletion (04 §8). Money is integer yen and never goes negative.

var cash_yen: int = 0
var transactions: Array[Dictionary] = []
var applied_event_ids: Dictionary = {}
## Several stores share one ledger (#146: one company purse). The store that books sets the scope ("" for the
## first store, "s2/" for the second ...): event ids get it as a prefix, so every store keeps its own ids
## ("0:DAILY_FIXED", "sale:res_...") and a one-store game books exactly the ids it always did.
var scope := ""


## The store an event id belongs to ("" = the first store).
static func store_of(event_id: String) -> String:
	var i := event_id.find("/")
	return event_id.substr(0, i) if i > 0 else ""


## Is this row the current scope's store's?
func is_mine(tx: Dictionary) -> bool:
	return store_of(String(tx["event_id"])) == scope.trim_suffix("/")


func has_event(event_id: String) -> bool:
	return applied_event_ids.has(scope + event_id)


## Returns false (and changes nothing) for a duplicate event id or when cash would go negative.
## Fixture purchases are capital expenditure: they move cash but carry no expense_delta.
## `amounts` carries the P&L side {revenue, cogs, expense}; wastage books expense with cash 0.
func record(event_type: String, event_id: String, cash_delta: int, day_index: int, time_sec: int, details: Dictionary = {}, amounts: Dictionary = {}) -> bool:
	if event_id.is_empty() or applied_event_ids.has(scope + event_id):
		return false
	if cash_yen + cash_delta < 0:
		return false
	cash_yen += cash_delta
	applied_event_ids[scope + event_id] = true
	transactions.append({
		"event_id": scope + event_id,
		"event_type": event_type,
		"day_index": day_index,
		"time_sec": time_sec,
		"cash_delta_yen": cash_delta,
		"revenue_delta_yen": int(amounts.get("revenue", 0)),
		"cogs_delta_yen": int(amounts.get("cogs", 0)),
		"expense_delta_yen": int(amounts.get("expense", 0)),
		"details": details,
	})
	return true
