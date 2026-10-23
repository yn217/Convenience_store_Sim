class_name DemandModel
extends RefCounted
## Potential-visitor probability per 2-game-second step (09 §2, 03 §F). Pure functions.

const STEPS_PER_DAY := 43200
const SECONDS_PER_DAY := 86400
const CATEGORY_COUNT := 8
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


static func reputation_multiplier(reputation: int) -> float:
	return 0.75 + 0.005 * clampi(reputation, 0, 100)


static func assortment_multiplier(stocked_categories: int) -> float:
	return 0.75 + 0.25 * clampi(stocked_categories, 0, CATEGORY_COUNT) / float(CATEGORY_COUNT)


## Multiplier of the advertising tier decided for today; unknown budgets count as no advertising.
static func ad_multiplier(tiers: Array, yen_per_day: int) -> float:
	for tier in tiers:
		if int(tier["yen_per_day"]) == yen_per_day:
			return float(tier["arrival_multiplier"])
	return 1.0


static func step_probability(hour: int, base_visits: float, ad_mult: float, reputation: int, stocked_categories: int) -> float:
	var weights := normalized_hour_weights()
	var p := base_visits * weights[clampi(hour, 0, 23)] * ad_mult * reputation_multiplier(reputation) * assortment_multiplier(stocked_categories) / STEPS_PER_DAY
	return clampf(p, 0.0, 1.0)
