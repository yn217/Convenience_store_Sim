class_name ReputationModel
extends RefCounted
## Daily reputation update (03 §F). Reputation is shown 0..100 and starts at 50. It moves by at
## most max_daily_change per game day, from the day's purchase rate, queue give-ups and
## stock-outs. A rate with a zero denominator counts as 0 (03 §F), so a day with no entered
## visitors nudges reputation down by the purchase-rate term.
##   delta = clamp(round(2*(purchase_rate - 0.5) - 2*queue_abandon_rate - stockout_rate), -3, +3)


static func rate(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)


static func daily_delta(visit_stats: Dictionary, rate_stats: Dictionary, balance: Dictionary = {}) -> int:
	var section = balance.get("demand_model", {})
	var u: Dictionary = section.get("reputation_update", {}) if typeof(section) == TYPE_DICTIONARY else {}
	var entered := int(visit_stats.get("entered", 0))
	var purchase_rate := rate(int(visit_stats.get("purchased", 0)), entered)
	var abandon_rate := rate(int(rate_stats.get("abandoned", 0)), entered)
	var stockout_rate := rate(int(rate_stats.get("stockouts", 0)), entered)
	var raw := float(u.get("purchase_rate_weight", 2.0)) * (purchase_rate - float(u.get("purchase_rate_center", 0.5))) \
		- float(u.get("queue_abandon_weight", 2.0)) * abandon_rate - float(u.get("stockout_weight", 1.0)) * stockout_rate
	var limit := int(u.get("max_daily_change", 3))
	return clampi(int(roundf(raw)), -limit, limit)


static func next_reputation(current: int, visit_stats: Dictionary, rate_stats: Dictionary, balance: Dictionary = {}) -> int:
	return clampi(current + daily_delta(visit_stats, rate_stats, balance), 0, 100)
