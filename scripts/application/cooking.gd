class_name Cooking
extends RefCounted
## Made-to-order goods, phase 1 (issue #131: soft serve and frappé). The machine holds the mix as its stock
## (ordered and restocked like any shelf, it keeps 2 days and is wasted after); a customer who wants one waits at
## the machine while it is made — prep_game_seconds of data/cooking/prep_v1.json, added to the time at the shelf —
## then takes it and pays at the till. Other goods have no making time. #130 phase 1: a pizza is baked to order at
## the pizza oven the same way; fresh bread is baked into the bakery oven's trays when restocked and keeps 8 hours.

const PATH := "res://data/cooking/prep_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"prep_game_seconds": {}}
	return _data


## Game seconds to make one item of this category (0 for goods taken off a shelf).
static func prep_seconds(category: String) -> int:
	return int((data()["prep_game_seconds"] as Dictionary).get(category, 0))
