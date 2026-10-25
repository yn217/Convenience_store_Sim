class_name LedgerSummary
extends RefCounted
## Profit-and-loss view of ledger rows (03 §G, 10 §D.9). Orders and fixture purchases move cash
## but are not expenses; COGS is booked at sale; wastage is booked at expiry with cash 0.
##   gross = revenue - cogs;  operating = gross - wastage - ad - electricity - fixed
##   cash  = initial + revenue - orders - capex - ad - electricity - fixed


## Sums rows of `day_index` (or all days when day_index < 0).
static func summarize(ledger: Ledger, day_index: int = -1) -> Dictionary:
	var out := {
		"revenue_yen": 0, "cogs_yen": 0, "wastage_yen": 0, "order_yen": 0, "capex_yen": 0,
		"advertising_yen": 0, "electricity_yen": 0, "fixed_cost_yen": 0, "wages_yen": 0, "promo_yen": 0, "discount_yen": 0, "cash_delta_yen": 0,
		"sale_count": 0, "units_sold": 0,
	}
	for tx in ledger.transactions:
		if day_index >= 0 and int(tx["day_index"]) != day_index:
			continue
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
			"AD":
				out["advertising_yen"] += int(tx["expense_delta_yen"])
			"ELECTRICITY":
				out["electricity_yen"] += int(tx["expense_delta_yen"])
			"DAILY_FIXED":
				out["fixed_cost_yen"] += int(tx["expense_delta_yen"])
			"WAGES":
				out["wages_yen"] += int(tx["expense_delta_yen"])
			"PROMO":
				out["promo_yen"] += int(tx["expense_delta_yen"])   # #137: setup of a promotion (POP, signs)
			"DISCOUNT":
				out["discount_yen"] += int(tx["expense_delta_yen"])   # #137: bundle discounts given at the till
	out["gross_profit_yen"] = out["revenue_yen"] - out["cogs_yen"]
	out["operating_profit_yen"] = out["gross_profit_yen"] - out["wastage_yen"] - out["advertising_yen"] - out["electricity_yen"] - out["fixed_cost_yen"] - out["wages_yen"] - out["promo_yen"] - out["discount_yen"]
	return out
