class_name StoreLocation
extends RefCounted
## Store locations (issue #148): station, school, office, residential (data/locations/locations_v1.json). A location
## shapes the day — the hourly visitor curve, how many come, why they come (purpose weights), what they like
## (category preferences), how much they spend and how easily they pick things up on the way. An unset location
## ("") is the neutral standard store: every multiplier 1 and the 09 §2 hour weights.

const PATH := "res://data/locations/locations_v1.json"

static var _data: Dictionary = {}


static func all() -> Array:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"locations": []}
	return _data["locations"]


static func find(location_id: String) -> Dictionary:
	if location_id == "":
		return {}
	for l in all():
		if l["location_id"] == location_id:
			return l
	return {}


static func display_name(location_id: String) -> String:
	var l := find(location_id)
	return "標準（指定なし）" if l.is_empty() else String(l["display_name"])


## The 24 hour weights normalised to mean 1 (DemandModel's own weights for the neutral store).
static func hour_weights(location_id: String) -> Array[float]:
	var l := find(location_id)
	if l.is_empty():
		return DemandModel.normalized_hour_weights()
	var raw: Array = l["hour_weights"]
	var total := 0.0
	for w in raw:
		total += float(w)
	var mean := total / 24.0
	var out: Array[float] = []
	for w in raw:
		out.append(float(w) / mean if mean > 0.0 else 1.0)
	return out


static func visitors_multiplier(location_id: String) -> float:
	return float(find(location_id).get("visitors_multiplier", 1.0))


static func purpose_multiplier(location_id: String, purpose_id: String) -> float:
	return float(find(location_id).get("purpose_multipliers", {}).get(purpose_id, 1.0))


static func category_multiplier(location_id: String, category: String) -> float:
	return float(find(location_id).get("category_multipliers", {}).get(category, 1.0))


static func budget_multiplier(location_id: String) -> float:
	return float(find(location_id).get("budget_multiplier", 1.0))


static func impulse_multiplier(location_id: String) -> float:
	return float(find(location_id).get("impulse_multiplier", 1.0))
