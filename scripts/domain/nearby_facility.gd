class_name NearbyFacility
extends RefCounted
## Nearby facilities (issue #149 phase 1, data/locations/facilities_v1.json): a university, a hotel, a hospital, a
## factory, a highway, a tourist spot. Up to max_count are chosen before the store first opens. Each one adds its own
## visitors on top of the location (#148): visitors_per_day spread over its hour weights, each visitor one of its
## customer segments (a statistical group of the surroundings) with one of the segment's visit purposes. A store
## without facilities draws nothing here, so its arrivals are exactly those of the location alone.
## Pure functions; the draws come from the caller's streams.

const PATH := "res://data/locations/facilities_v1.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {"facilities": [], "max_facilities": 0}
	return _data


static func all() -> Array:
	return data()["facilities"]


static func max_count() -> int:
	return int(data().get("max_facilities", 2))


static func find(facility_id: String) -> Dictionary:
	for f in all():
		if f["facility_id"] == facility_id:
			return f
	return {}


static func display_name(facility_id: String) -> String:
	return String(find(facility_id).get("display_name", ""))


## Segment display name by id ("" when unknown).
static func segment_name(segment_id: String) -> String:
	for f in all():
		for seg in f["segments"]:
			if seg["segment_id"] == segment_id:
				return String(seg["display_name"])
	return ""


## Probability that the facility sends a visitor in one step of `hour`: its daily visitors times the hour's share,
## per step, times the day's traffic effect; at most 0.5.
static func step_probability(f: Dictionary, hour: int, traffic: float = 1.0) -> float:
	var w: Array = f["hour_weights"]
	var total := 0.0
	for x in w:
		total += float(x)
	if total <= 0.0:
		return 0.0
	var steps_per_hour := 3600.0 / GameClock.STEP_GAME_SECONDS
	return clampf(float(f["visitors_per_day"]) * float(w[hour]) / total / steps_per_hour * traffic, 0.0, 0.5)


## A visitor of facility `f`: one draw picks the segment (by weight), one the purpose (by the segment's weights,
## skipping purposes whose first target the store does not carry). -> {segment_id, purpose_id} or {} when none of
## its purposes can be served (nobody comes).
static func draw_visitor(pick_rng: Lcg32, f: Dictionary, balance: Dictionary, stocked: Array) -> Dictionary:
	var segs: Array = f["segments"]
	var total := 0.0
	for seg in segs:
		total += float(seg["weight"])
	var roll := pick_rng.uniform_0_1() * total
	var seg: Dictionary = segs[0]
	var acc := 0.0
	for s in segs:
		acc += float(s["weight"])
		if roll < acc:
			seg = s
			break
	var options: Array = []
	var sum := 0.0
	var ids: Array = (seg["purposes"] as Dictionary).keys()
	ids.sort()
	for pid in ids:
		var p := VisitPurpose.find(balance, pid)
		if p.is_empty() or not VisitPurpose.serves(p, stocked):
			continue
		options.append([pid, float(seg["purposes"][pid])])
		sum += float(seg["purposes"][pid])
	var proll := pick_rng.uniform_0_1() * sum
	if options.is_empty() or sum <= 0.0:
		return {}
	var chosen: String = options[0][0]
	var pacc := 0.0
	for o in options:
		pacc += float(o[1])
		if proll < pacc:
			chosen = o[0]
			break
	return {"segment_id": seg["segment_id"], "purpose_id": chosen}
