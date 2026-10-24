class_name BasketModel
extends RefCounted
## Basket size of one visit (issue #128). Drawn once per entering customer from the `arrivals` stream
## (distribution in balance["basket_size_distribution"], integer weights). A balance without the
## distribution, or with `basket_size_forced` (test override), uses 1 item and consumes no draw, so the
## single-item model stays bit-for-bit identical. Pure functions.

const MIN_SIZE := 1
const MAX_SIZE := 4
const DEFAULT_CHECKOUT_BASE_SEC := 20
const DEFAULT_CHECKOUT_PER_ITEM_SEC := 8


## Forced size (test override) when > 0, else the distribution draw, else 1 without a distribution.
static func draw_size(rng: Lcg32, balance: Dictionary) -> int:
	var forced := int(balance.get("basket_size_forced", 0))
	if forced > 0:
		return clampi(forced, MIN_SIZE, MAX_SIZE)
	var dist := distribution(balance)
	if dist.is_empty():
		return MIN_SIZE
	var total := 0
	for e in dist:
		total += int(e["weight"])
	var pick := int(rng.uniform_0_1() * total)
	var acc := 0
	for e in dist:
		acc += int(e["weight"])
		if pick < acc:
			return int(e["basket_size"])
	return int(dist[dist.size() - 1]["basket_size"])


## Valid entries only: {basket_size, weight} with the size inside MIN..MAX and a positive weight.
static func distribution(balance: Dictionary) -> Array:
	var out: Array = []
	var raw = balance.get("basket_size_distribution", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in raw:
		if typeof(e) == TYPE_DICTIONARY and e.has("basket_size") and e.has("weight"):
			var size := int(e["basket_size"])
			var weight := int(e["weight"])
			if size >= MIN_SIZE and size <= MAX_SIZE and weight > 0:
				out.append({"basket_size": size, "weight": weight})
	return out


## Expected items per visit under the distribution (1.0 without one).
static func mean_size(balance: Dictionary) -> float:
	var dist := distribution(balance)
	if dist.is_empty():
		return 1.0
	var total := 0.0
	var weighted := 0.0
	for e in dist:
		total += float(e["weight"])
		weighted += float(e["weight"]) * float(e["basket_size"])
	return weighted / total


## Checkout length in game seconds for `items` reserved items: base + per item.
static func checkout_seconds(balance: Dictionary, items: int) -> int:
	return int(balance.get("checkout_base_game_seconds", DEFAULT_CHECKOUT_BASE_SEC)) + int(balance.get("checkout_per_item_game_seconds", DEFAULT_CHECKOUT_PER_ITEM_SEC)) * maxi(items, 1)
