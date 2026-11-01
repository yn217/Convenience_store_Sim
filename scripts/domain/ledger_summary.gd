class_name LedgerSummary
extends RefCounted
## Profit-and-loss view of ledger rows (03 §G, 10 §D.9). Orders and fixture purchases move cash
## but are not expenses; COGS is booked at sale; wastage is booked at expiry with cash 0.
##   gross = revenue - cogs;  operating = gross - wastage - ad - electricity - fixed
##   cash  = initial + revenue - orders - capex - ad - electricity - fixed


## Sums rows of `day_index` (or all days when day_index < 0). `recent`: walk back from the newest row and stop a day
## before `day_index` (rows are appended in time order): for views of today, where a walk over the whole history
## would grow with every day played. Reports and saves use the full walk.
static func summarize(ledger: Ledger, day_index: int = -1, recent: bool = false) -> Dictionary:
	var out := empty()
	var rows: Array = ledger.transactions
	var n := rows.size()
	var backwards := recent and day_index >= 0
	for k in n:
		var tx: Dictionary = rows[n - 1 - k] if backwards else rows[k]
		if backwards and int(tx["day_index"]) < day_index - 1:
			break
		if day_index >= 0 and int(tx["day_index"]) != day_index:
			continue
		if not ledger.is_mine(tx):
			continue   # another store of the company (#146)
		add_row(out, tx)
	return finish(out)


## The sums before any row (SalesIndex keeps one per day and adds rows as they come).
static func empty() -> Dictionary:
	return {
		"revenue_yen": 0, "cogs_yen": 0, "wastage_yen": 0, "order_yen": 0, "capex_yen": 0,
		"advertising_yen": 0, "electricity_yen": 0, "fixed_cost_yen": 0, "wages_yen": 0, "promo_yen": 0, "discount_yen": 0, "cash_delta_yen": 0,
		"sale_count": 0, "units_sold": 0,
	}


## Adds one ledger row (already known to be this store's) to the sums.
static func add_row(out: Dictionary, tx: Dictionary) -> void:
	out["cash_delta_yen"] += int(tx["cash_delta_yen"])
	match tx["event_type"]:
		"SALE":
			out["revenue_yen"] += int(tx["revenue_delta_yen"])
			out["cogs_yen"] += int(tx["cogs_delta_yen"])
			out["sale_count"] += 1
			out["units_sold"] += int(tx["details"].get("qty", 1))
		"WASTAGE":
			out["wastage_yen"] += int(tx["expense_delta_yen"])
		"ORDER":
			out["order_yen"] += -int(tx["cash_delta_yen"])
		"FIXTURE_PURCHASE", "REVERSAL":
			out["capex_yen"] += -int(tx["cash_delta_yen"])
		"AD", "AD_SETUP", "AD_MEDIA":   # #136: media campaigns are advertising too
			out["advertising_yen"] += int(tx["expense_delta_yen"])
		"ELECTRICITY":
			out["electricity_yen"] += int(tx["expense_delta_yen"])
		"DAILY_FIXED", "REPAIR":   # #132: a machine repair counts with the fixed running costs
			out["fixed_cost_yen"] += int(tx["expense_delta_yen"])
		"WAGES":
			out["wages_yen"] += int(tx["expense_delta_yen"])
		"PROMO":
			out["promo_yen"] += int(tx["expense_delta_yen"])   # #137: setup of a promotion (POP, signs)
		"DISCOUNT":
			out["discount_yen"] += int(tx["expense_delta_yen"])   # #137: bundle discounts given at the till


## A copy of the sums with gross and operating profit filled in.
static func finish(sums: Dictionary) -> Dictionary:
	var out := sums.duplicate()
	out["gross_profit_yen"] = out["revenue_yen"] - out["cogs_yen"]
	out["operating_profit_yen"] = out["gross_profit_yen"] - out["wastage_yen"] - out["advertising_yen"] - out["electricity_yen"] - out["fixed_cost_yen"] - out["wages_yen"] - out["promo_yen"] - out["discount_yen"]
	return out
