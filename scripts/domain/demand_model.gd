class_name DemandModel
extends RefCounted
## Potential-visitor probability per 2-game-second step (09 §2, 03 §F). Pure functions.

const STEPS_PER_DAY := 43200
const SECONDS_PER_DAY := 86400
const CATEGORY_COUNT := 8   # the assortment bonus counts up to 8 stocked categories (more do not add, #147)
## 09 §2: raw weight per hour of day.
const RAW_HOUR_WEIGHTS: Array[float] = [
	0.5, 0.5, 0.5, 0.5, 0.5, 0.5,
	1.25, 1.25, 1.25, 1.25, 1.25,
	1.75, 1.75, 1.75,
	1.0, 1.0, 1.0,
	1.5, 1.5, 1.5, 1.5,
	0.75, 0.75, 0.75,
]


## raw[h] / mean(raw), so the 24 weights sum to 24.
static func normalized_hour_weights() -> Array[float]:
	var total := 0.0
	for w in RAW_HOUR_WEIGHTS:
		total += w
	var mean := total / 24.0
	var out: Array[float] = []
	for w in RAW_HOUR_WEIGHTS:
		out.append(w / mean)
	return out


static func hour_of_day(time_sec: int) -> int:
	return (time_sec % SECONDS_PER_DAY) / 3600


## Coefficient from balance["demand_model"], falling back to the 09 §2/§3 defaults.
static func param(balance: Dictionary, key: String, default_value: float) -> float:
	var section = balance.get("demand_model", {})
	if typeof(section) == TYPE_DICTIONARY and section.has(key):
		return float(section[key])
	return default_value


## Traffic effect of reputation (0..100): 0.75 .. 1.25 with the defaults.
static func reputation_multiplier(reputation: int, balance: Dictionary = {}) -> float:
	return param(balance, "reputation_base", 0.75) + param(balance, "reputation_per_point", 0.005) * clampi(reputation, 0, 100)


## Traffic effect of the range on offer: how many of the 8 categories have stock on a shelf.
static func assortment_multiplier(stocked_categories: int, balance: Dictionary = {}) -> float:
	return param(balance, "assortment_base", 0.75) + param(balance, "assortment_span", 0.25) * clampi(stocked_categories, 0, CATEGORY_COUNT) / float(CATEGORY_COUNT)


## Price attractiveness: clamp((reference / price) ^ elasticity, min, max). A price below 1 is
## treated as 1 so a bad value can never divide by zero.
static func price_factor(reference_yen: int, price_yen: int, balance: Dictionary = {}) -> float:
	var ratio := float(reference_yen) / float(maxi(price_yen, 1))
	return clampf(pow(ratio, param(balance, "price_elasticity", 1.0)), param(balance, "price_factor_min", 0.3), param(balance, "price_factor_max", 2.0))


## Chance that a customer who picked an item really buys it at that price factor.
static func purchase_probability(factor: float, balance: Dictionary = {}) -> float:
	return clampf(param(balance, "base_purchase_probability", 0.80) * factor, param(balance, "purchase_probability_min", 0.05), param(balance, "purchase_probability_max", 0.95))


static func category_preference(category: String, balance: Dictionary = {}) -> float:
	var section = balance.get("demand_model", {})
	if typeof(section) == TYPE_DICTIONARY and typeof(section.get("category_preference")) == TYPE_DICTIONARY and section["category_preference"].has(category):
		return float(section["category_preference"][category])
	return 1.0


## Multiplier of the advertising tier decided for today; unknown budgets count as no advertising.
static func ad_multiplier(tiers: Array, yen_per_day: int) -> float:
	for tier in tiers:
		if int(tier["yen_per_day"]) == yen_per_day:
			return float(tier["arrival_multiplier"])
	return 1.0


## `hour_weights`: the store location's normalised curve (StoreLocation.hour_weights, #148); [] = the 09 §2 one.
static func step_probability(hour: int, base_visits: float, ad_mult: float, reputation: int, stocked_categories: int, balance: Dictionary = {}, event_traffic: float = 1.0, hour_weights: Array = []) -> float:
	var weights: Array = hour_weights if hour_weights.size() == 24 else normalized_hour_weights()
	var p: float = base_visits * float(weights[clampi(hour, 0, 23)]) * ad_mult * reputation_multiplier(reputation, balance) * assortment_multiplier(stocked_categories, balance) * event_traffic / STEPS_PER_DAY
	return clampf(p, 0.0, 1.0)
