class_name Lottery
extends RefCounted
## Prize draws at the till, phase 1 (issue #138, data/lottery/lottery_v1.json). The manager buys a whole set (an
## ORDER of set_cost_yen) and it sells one ticket at a time at the till for its days. Every ticket wins one prize:
## the tickets are drawn without replacement from an order shuffled when the set is bought (seeded by the command
## id and kept in state.lotteries, so a loaded game never draws again); the last ticket also gets the last_one
## prize. Each ticket is a SALE row of its own (revenue: the price; cost: its share of the set cost). A customer at
## the till buys one with buy_rate x hype (hype_start falling to hype_end over the days, x top_bonus while the top
## prize is left) — `impulse` draws, only while a set sells — and a second one with second_rate, within the cash
## left. Tickets left at the end are written off (WASTAGE, their share of the set cost). One set at a time.

const PATH := "res://data/lottery/lottery_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"sets": []}
	return _data


static func definition(set_id: String) -> Dictionary:
	for d in data()["sets"]:
		if d["set_id"] == set_id:
			return d
	return {}


static func total_tickets(d: Dictionary) -> int:
	var n := 0
	for p in d["prizes"]:
		n += int(p["count"])
	return n


static func selling(state: GameState) -> Array:
	return state.lotteries.filter(func(l): return l["status"] == "selling" and int(l["start_day"]) <= state.day and state.day <= int(l["end_day"]))


## Buys a set and starts selling it today. -> "" or an error key.
static func start(state: GameState, command_id: String, set_id: String) -> String:
	var d := definition(set_id)
	if d.is_empty():
		return "unknown_set"
	if state.lotteries.any(func(l): return l["status"] == "selling"):
		return "lottery_running"
	var id := "kuji_%03d" % (state.lotteries.size() + 1)
	if not state.ledger.record("ORDER", "%s:KUJI" % command_id, -int(d["set_cost_yen"]), state.day, state.time_sec, {"lottery_id": id, "set_id": set_id}):
		return "not_enough_cash"
	var order: Array = []
	for p in d["prizes"]:
		for i in int(p["count"]):
			order.append(String(p["tier"]))
	var rng := Lcg32.new(command_id.hash() & 0x7fffffff)
	for i in range(order.size() - 1, 0, -1):   # Fisher-Yates
		var j := mini(int(rng.uniform_0_1() * float(i + 1)), i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	state.lotteries.append({"lottery_id": id, "set_id": set_id, "start_day": state.day, "end_day": state.day + int(d["days"]) - 1,
		"order": order, "sold": 0, "status": "selling", "revenue_yen": 0})
	return ""


## The share of the set cost carried by tickets [from, to) (whole yen; all of them add up to the set cost).
static func _cost_share(d: Dictionary, from: int, to: int) -> int:
	var total := total_tickets(d)
	var cost := int(d["set_cost_yen"])
	return cost * to / total - cost * from / total


static func prize_name(d: Dictionary, tier: String) -> String:
	for p in d["prizes"]:
		if p["tier"] == tier:
			return String(p["name"])
	return ""


## Sells the next ticket of a set. -> {tier, name, last_one} or {} when none is left.
static func sell_ticket(state: GameState, lot: Dictionary, customer_id: String) -> Dictionary:
	var d := definition(lot["set_id"])
	var order: Array = lot["order"]
	var n := int(lot["sold"])
	if n >= order.size() or lot["status"] != "selling":
		return {}
	var price := int(d["ticket_price_yen"])
	var tier := String(order[n])
	if not state.ledger.record("SALE", "kuji:%s:%d" % [lot["lottery_id"], n], price, state.day, state.time_sec,
			{"lottery_id": lot["lottery_id"], "ticket": n, "tier": tier, "qty": 1, "customer_id": customer_id}, {"revenue": price, "cogs": _cost_share(d, n, n + 1)}):
		return {}
	lot["sold"] = n + 1
	lot["revenue_yen"] = int(lot["revenue_yen"]) + price
	var prize := {"tier": tier, "name": prize_name(d, tier), "last_one": n + 1 == order.size()}
	if tier == String(d["prizes"][0]["tier"]):
		state.emit_event("LOTTERY_TOP", {"lottery_id": lot["lottery_id"], "set": d["display_name"], "prize": prize["name"]})
	if prize["last_one"]:
		lot["status"] = "sold_out"
		state.emit_event("LOTTERY_SOLD_OUT", {"lottery_id": lot["lottery_id"], "set": d["display_name"], "last_one": d["last_one"]})
	return prize


## Tickets left per tier of a set. -> {tier: n}.
static func remaining(lot: Dictionary) -> Dictionary:
	var out := {}
	for p in definition(lot["set_id"])["prizes"]:
		out[p["tier"]] = 0
	var order: Array = lot["order"]
	for i in range(int(lot["sold"]), order.size()):
		out[order[i]] = int(out.get(order[i], 0)) + 1
	return out


## How keen customers are on a set today (buy_rate x hype x top_bonus while the top prize is left).
static func appetite(state: GameState, lot: Dictionary) -> float:
	var g := data()
	var d := definition(lot["set_id"])
	var span := maxf(float(int(lot["end_day"]) - int(lot["start_day"])), 1.0)
	var t := clampf(float(state.day - int(lot["start_day"])) / span, 0.0, 1.0)
	var k := float(g["buy_rate"]) * lerpf(float(g["hype_start"]), float(g["hype_end"]), t)
	if int(remaining(lot).get(d["prizes"][0]["tier"], 0)) > 0:
		k *= float(g["top_bonus"])
	return k


## A customer at the till (#138): may buy a ticket of the selling set, and a second one, within the cash left.
## -> the prizes won.
static func at_till(state: GameState, c: Dictionary) -> Array:
	var won: Array = []
	for lot in selling(state):
		var price := int(definition(lot["set_id"])["ticket_price_yen"])
		var p := appetite(state, lot)
		for k in 2:
			if int(c.get("wallet_yen", 0)) - int(c.get("planned_yen", 0)) < price:
				break
			var rng := Lcg32.new(int(state.rng_states["impulse"]))
			var roll := rng.uniform_0_1()
			state.rng_states["impulse"] = rng.state
			if roll >= p:
				break
			var prize := sell_ticket(state, lot, String(c.get("customer_id", "")))
			if prize.is_empty():
				break
			c["planned_yen"] = int(c.get("planned_yen", 0)) + price
			won.append(prize)
			p = float(data()["second_rate"])
	return won


## At midnight: a set past its last day stops; the tickets left are written off at their share of the set cost.
static func close_expired(state: GameState) -> void:
	for lot in state.lotteries:
		if lot["status"] != "selling" or int(lot["end_day"]) >= state.day:
			continue
		lot["status"] = "ended"
		var d := definition(lot["set_id"])
		var left := (lot["order"] as Array).size() - int(lot["sold"])
		if left > 0:
			state.ledger.record("WASTAGE", "kuji_left:%s" % lot["lottery_id"], 0, state.day, state.time_sec,
				{"lottery_id": lot["lottery_id"], "qty": left}, {"expense": _cost_share(d, int(lot["sold"]), (lot["order"] as Array).size())})
		state.emit_event("LOTTERY_ENDED", {"lottery_id": lot["lottery_id"], "set": d["display_name"], "left": left})


## A set whose top prize is left keeps a few more people coming (1 without).
static func visitor_factor(state: GameState) -> float:
	for lot in selling(state):
		var d := definition(lot["set_id"])
		if int(remaining(lot).get(d["prizes"][0]["tier"], 0)) > 0:
			return float(data()["visitors"])
	return 1.0


## For the 店頭くじ card: every set, with its latest run (if any).
static func views(state: GameState) -> Array:
	var out: Array = []
	for d in data()["sets"]:
		var v: Dictionary = d.duplicate(true)
		v["tickets"] = total_tickets(d)
		v["run"] = {}
		for lot in state.lotteries:
			if lot["set_id"] == d["set_id"]:
				v["run"] = {"lottery_id": lot["lottery_id"], "status": lot["status"], "sold": lot["sold"], "revenue_yen": lot["revenue_yen"],
					"days_left": int(lot["end_day"]) - state.day + 1, "remaining": remaining(lot)}
		out.append(v)
	return out
