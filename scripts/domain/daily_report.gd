class_name DailyReport
extends RefCounted
## One closed game day (savegame.schema.json `daily_reports`). The ledger is the only source of
## money figures: revenue/COGS/wastage/costs come from LedgerSummary rows of that day, cash is the
## balance at close. Accounting profit and cash are separate: orders and fixtures move cash but
## are not part of gross/operating profit.

const FIELDS: Array[String] = [
	"day_index", "revenue_yen", "cogs_yen", "gross_profit_yen", "wastage_yen", "advertising_yen",
	"electricity_yen", "fixed_cost_yen", "operating_profit_yen", "net_cash_delta_yen", "cash_end_yen",
	"store_reputation", "potential_customers", "visitors", "purchasing_customers", "lost_customers", "units_sold",
]


static func build(day_index: int, ledger: Ledger, stats: Dictionary, reputation: int, cash_end_yen: int) -> Dictionary:
	var sum := LedgerSummary.summarize(ledger, day_index)
	return {
		"day_index": day_index,
		"revenue_yen": sum["revenue_yen"],
		"cogs_yen": sum["cogs_yen"],
		"gross_profit_yen": sum["gross_profit_yen"],
		"wastage_yen": sum["wastage_yen"],
		"advertising_yen": sum["advertising_yen"],
		"electricity_yen": sum["electricity_yen"],
		"fixed_cost_yen": sum["fixed_cost_yen"],
		"operating_profit_yen": sum["operating_profit_yen"],
		"net_cash_delta_yen": sum["cash_delta_yen"],
		"cash_end_yen": cash_end_yen,
		"store_reputation": reputation,
		"potential_customers": int(stats.get("potential", 0)),
		"visitors": int(stats.get("entered", 0)),
		"purchasing_customers": int(stats.get("purchased", 0)),
		"lost_customers": int(stats.get("lost", 0)),
		"units_sold": sum["units_sold"],
	}


## Gross margin in percent, or null when there was no revenue (shown as "—", never NaN).
static func gross_margin_percent(report: Dictionary):
	var revenue := int(report["revenue_yen"])
	if revenue <= 0:
		return null
	return 100.0 * float(report["gross_profit_yen"]) / float(revenue)


## Change of `key` against the previous day; null when there is no previous day.
static func day_over_day(reports: Array, key: String):
	if reports.size() < 2:
		return null
	return int(reports[reports.size() - 1][key]) - int(reports[reports.size() - 2][key])


## Structural check used by save/load: every field present, integers, no negative counts.
static func errors(report) -> Array[String]:
	var errs: Array[String] = []
	if typeof(report) != TYPE_DICTIONARY:
		errs.append("not_object")
		return errs
	for f in FIELDS:
		if not report.has(f):
			errs.append("%s: missing" % f)
		elif typeof(report[f]) != TYPE_INT:
			errs.append("%s: not_integer" % f)
	if errs.is_empty():
		for f in ["wastage_yen", "advertising_yen", "electricity_yen", "fixed_cost_yen", "cogs_yen", "revenue_yen", "potential_customers", "visitors", "purchasing_customers", "lost_customers", "units_sold", "cash_end_yen"]:
			if int(report[f]) < 0:
				errs.append("%s: negative" % f)
		if int(report["store_reputation"]) < 0 or int(report["store_reputation"]) > 100:
			errs.append("store_reputation: out_of_range")
	return errs
