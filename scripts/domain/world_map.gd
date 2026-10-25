class_name WorldMap
extends RefCounted
## Area map (issue #150 phase 1): one fictional town (data/world/maps/<map_id>.json, from design PR #152) with its
## roads, railway, zones, facilities (POIs) and store sites (plots). The player picks the first store's site on the
## map before it first opens; the site gives the store its location profile (#148) and its nearby facilities (#149):
## the facility POIs within NEAR_RADIUS map units, nearest first, at most NearbyFacility.max_count(). Plots marked
## "locked" (later releases) and the rival plot cannot be picked. Positions are map units, not real distances.

const DIR := "res://data/world/maps/"
const DEFAULT_MAP := "aoba_town_v1"
const NEAR_RADIUS := 230.0
## POI type -> NearbyFacility id.
const FACILITY_OF := {
	"university": "university", "hotel": "hotel", "hospital": "hospital", "logistics": "factory",
	"tourism": "tourist_spot", "road_hub": "highway",
}

static var _maps: Dictionary = {}


static func load_map(map_id: String) -> Dictionary:
	if not _maps.has(map_id):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + map_id + ".json")) if FileAccess.file_exists(DIR + map_id + ".json") else null
		_maps[map_id] = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _maps[map_id]


static func plot(map_id: String, plot_id: String) -> Dictionary:
	for p in load_map(map_id).get("plots", []):
		if p["id"] == plot_id:
			return p
	return {}


static func poi(map_id: String, poi_id: String) -> Dictionary:
	for p in load_map(map_id).get("pois", []):
		if p["id"] == poi_id:
			return p
	return {}


## Can a store open on this plot (available, with a location profile)?
static func pickable(p: Dictionary) -> bool:
	return String(p.get("status", "")) == "available" and not StoreLocation.find(String(p.get("location_id", ""))).is_empty()


## Facility POIs near a plot, nearest first: [{facility_id, poi_id, name, distance}], one per facility kind, at most
## NearbyFacility.max_count().
static func facilities_near(map_id: String, p: Dictionary) -> Array:
	var found: Array = []
	for q in load_map(map_id).get("pois", []):
		if not FACILITY_OF.has(q["type"]):
			continue
		var d := Vector2(float(q["x"]) - float(p["x"]), float(q["y"]) - float(p["y"])).length()
		if d <= NEAR_RADIUS:
			found.append({"facility_id": FACILITY_OF[q["type"]], "poi_id": q["id"], "name": q["name"], "distance": int(round(d))})
	found.sort_custom(func(a, b): return a["distance"] < b["distance"] or (a["distance"] == b["distance"] and a["poi_id"] < b["poi_id"]))
	var out: Array = []
	var kinds := {}
	for f in found:
		if kinds.has(f["facility_id"]) or out.size() >= NearbyFacility.max_count():
			continue
		kinds[f["facility_id"]] = true
		out.append(f)
	return out


## What opening on a plot means: {location_id, facilities (ids), near (facilities_near)} or {} when it cannot be picked.
static func site(map_id: String, plot_id: String) -> Dictionary:
	var p := plot(map_id, plot_id)
	if p.is_empty() or not pickable(p):
		return {}
	var near := facilities_near(map_id, p)
	return {"location_id": String(p["location_id"]), "facilities": near.map(func(f): return f["facility_id"]), "near": near}


## Rough visitors per day for a plot (the location's share of the balance's base, plus the facilities' visitors):
## a forecast for the map panel, not a promise.
static func forecast_visitors(balance: Dictionary, map_id: String, plot_id: String) -> int:
	var s := site(map_id, plot_id)
	if s.is_empty():
		return 0
	var n := float(balance.get("base_potential_visitors_per_day", 100)) * StoreLocation.visitors_multiplier(s["location_id"])
	for fid in s["facilities"]:
		n += float(NearbyFacility.find(fid).get("visitors_per_day", 0))
	return int(round(n))
