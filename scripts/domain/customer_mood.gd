class_name CustomerMood
extends RefCounted
## Mood of a customer (issue #141), 0..100 with 70 at the door, read off what happened on the visit — it has no state
## of its own and changes no decision (phase 1: shown on the customer panel and as the day's satisfaction):
## -15 per wanted item found sold out, -5 per item left for being over the budget, +5 per item bought on impulse or
## on a deal, +5 for a coupon used, a novelty or a prize draw won, +5 for a seat at the eat-in; -3 per minute in the
## line past the first two (until the till, or now), and -30 for giving up in the line.

const START := 70
const SATISFIED := 75
const UNHAPPY := 50


static func of(c: Dictionary, now_sec: int) -> int:
	var m := START
	for e in c.get("basket_log", []):
		match String(e.get("state", "")):
			"stockout":
				m -= 15
			"too_expensive":
				m -= 5
			"taken":
				if ["impulse", "deal"].has(String(e.get("kind", ""))):
					m += 5
	if bool(c.get("coupon_used", false)):
		m += 5
	if not (c.get("gifts", []) as Array).is_empty() or not (c.get("kuji", []) as Array).is_empty():
		m += 5
	if c.has("seat") or String(c.get("phase", "")) == "EAT":
		m += 5
	m -= 3 * maxi(waited_minutes(c, now_sec) - 2, 0)
	if String(c.get("outcome", "")) == "queue_timeout":
		m -= 30
	return clampi(m, 0, 100)


## Whole minutes in the line: from reaching it to the till (waited_sec, set at the till), or until now.
static func waited_minutes(c: Dictionary, now_sec: int) -> int:
	if c.has("waited_sec"):
		return int(c["waited_sec"]) / 60
	if ["WAIT_QUEUE", "QUEUE"].has(String(c.get("phase", ""))) and int(c.get("queue_since", 0)) > 0:
		return (now_sec - int(c["queue_since"])) / 60
	return 0


static func band(mood: int) -> String:
	if mood >= SATISFIED:
		return "満足"
	return "ふつう" if mood >= UNHAPPY else "不満"
