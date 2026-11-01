class_name EatIn
extends RefCounted
## Eat-in, phase 1 (issue #134, data/eat_in/eat_in_v1.json). The seats of an eat-in counter are the floor tiles in
## front of it (its access side). After paying, a customer whose basket holds something to eat here takes a free
## seat with the eat_share of its categories — decided by a hash of the customer id, no random draw — and stays
## stay_game_seconds (same hash) before leaving; with every seat taken it simply leaves. The sale stays the till's;
## sitting never causes a second checkout. A store without a counter behaves as before.

const PATH := "res://data/eat_in/eat_in_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"fixture_types": [], "eat_share": {}, "stay_game_seconds": [0, 0]}
	return _data


static func is_counter(type_id: String) -> bool:
	return (data()["fixture_types"] as Array).has(type_id)


## Placed eat-in counters (instance ids, sorted).
static func counters(state: GameState) -> Array:
	var out: Array = []
	for id in state.grid.instances:
		if is_counter(String(state.grid.instances[id]["type_id"])):
			out.append(id)
	out.sort()
	return out


static func _unit(customer_id: String, salt: String) -> float:
	return float(absi(("%s|%s" % [customer_id, salt]).hash()) % 10000) / 10000.0


## Does this customer eat here? The highest eat_share among the categories bought, against the customer's hash.
static func wants(customer_id: String, categories: Array) -> bool:
	var share := 0.0
	for c in categories:
		share = maxf(share, float((data()["eat_share"] as Dictionary).get(c, 0.0)))
	return share > 0.0 and _unit(customer_id, "eat") < share


## Game seconds the customer stays at the seat.
static func stay_seconds(customer_id: String) -> int:
	var r: Array = data()["stay_game_seconds"]
	return int(r[0]) + int(_unit(customer_id, "stay") * float(int(r[1]) - int(r[0])))
