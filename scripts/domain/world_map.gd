class_name WorldMap
extends RefCounted
## Area maps (issue #150): data/world/maps/<map_id>.json — the fictional 青葉市 (design PR #152, drawn in code from its
## roads, railway and zones) and the Kakogawa concept map (#154, user package of 2026-10-26, drawn on its background
## image) — with facilities (POIs) and store sites (plots). The player picks the first store's site on a map before it
## first opens; the site gives the store its location profile (#148) and its nearby facilities (#149): the facility
## POIs within NEAR_SHARE of the map's width, nearest first, at most NearbyFacility.max_count(). A site whose kind is
## not one of the four profiles (riverside, factory, commercial, roadside) opens as the standard store and gets its
## character from the facilities around it (a roadside site always has the trunk road). Plots marked "locked" (later
## releases) and rival plots cannot be picked. Positions are map units / image pixels, not real distances.

const DIR := "res://data/world/maps/"
const DEFAULT_MAP := "aoba_town_v1"
const MAPS := ["aoba_town_v1", "kakogawa_city_v1"]
## Maps drawn on a picture (the others are drawn in code from their features).
const BACKGROUND := {"kakogawa_city_v1": "res://assets/generated/maps/kakogawa_city_v1/kakogawa_base.png"}
const NEAR_SHARE := 0.23          # 230 map units on the 1000-wide 青葉市 map
## POI type -> NearbyFacility id.
const FACILITY_OF := {
	"university": "university", "hotel": "hotel", "hospital": "hospital", "medical": "hospital", "logistics": "factory",
	"industrial": "factory", "tourism": "tourist_spot", "leisure": "tourist_spot", "road_hub": "highway",
}
## Site kinds without a location profile: opened as the standard store.
const STANDARD_KINDS := ["tourism", "industrial", "commercial", "roadside"]
const KIND_NAMES := {"tourism": "観光・河川敷", "industrial": "物流・工場", "commercial": "商業施設", "roadside": "幹線道路沿い"}

static var _maps: Dictionary = {}


static func load_map(map_id: String) -> Dictionary:
	if not _maps.has(map_id):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + map_id + ".json")) if FileAccess.file_exists(DIR + map_id + ".json") else null
		_maps[map_id] = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _maps[map_id]


static func display_name(map_id: String) -> String:
	var m := load_map(map_id)
	return String(m.get("display_name", m.get("name", map_id)))


## Width and height of the map's coordinates (map units, or image pixels for a picture map).
static func map_size(map_id: String) -> Vector2:
	var cs: Dictionary = load_map(map_id).get("coordinate_system", {})
	return Vector2(float(cs.get("width", cs.get("width_px", 1000))), float(cs.get("height", cs.get("height_px", 680))))


static func plot_status(p: Dictionary) -> String:
	return String(p.get("status", "available"))


## The site's kind as the map names it (location_id in 青葉市, location_type in Kakogawa).
static func plot_kind(p: Dictionary) -> String:
	return String(p.get("location_id", p.get("location_type", "")))


## The location profile a site opens with ("" = the standard store).
static func plot_location(p: Dictionary) -> String:
	var kind := plot_kind(p)
	return kind if not StoreLocation.find(kind).is_empty() else ""


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


## Can a store open on this plot (available, a location profile or a kind opened as the standard store)?
static func pickable(p: Dictionary) -> bool:
	return plot_status(p) == "available" and (plot_location(p) != "" or STANDARD_KINDS.has(plot_kind(p)))


## Facility POIs near a plot, nearest first: [{facility_id, poi_id, name, distance}], one per facility kind, at most
## NearbyFacility.max_count().
static func facilities_near(map_id: String, p: Dictionary) -> Array:
	var found: Array = []
	if plot_kind(p) == "roadside":
		found.append({"facility_id": "highway", "poi_id": "", "name": "幹線道路", "distance": 0})
	var radius := NEAR_SHARE * map_size(map_id).x
	for q in load_map(map_id).get("pois", []):
		if not FACILITY_OF.has(q["type"]):
			continue
		var d := Vector2(float(q["x"]) - float(p["x"]), float(q["y"]) - float(p["y"])).length()
		if d <= radius:
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
	return {"location_id": plot_location(p), "facilities": near.map(func(f): return f["facility_id"]), "near": near}


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


## The forecast by hour (24 values, visitors in that hour): the location's share of the day by its hour curve plus
## each facility's visitors by its own hours. Same rough basis as forecast_visitors (no ads, events or stock).
static func forecast_by_hour(balance: Dictionary, map_id: String, plot_id: String) -> Array[float]:
	var out: Array[float] = []
	out.resize(24)
	out.fill(0.0)
	var s := site(map_id, plot_id)
	if s.is_empty():
		return out
	var daily := float(balance.get("base_potential_visitors_per_day", 100)) * StoreLocation.visitors_multiplier(s["location_id"])
	var curve := StoreLocation.hour_weights(s["location_id"])   # mean 1
	for h in 24:
		out[h] = daily * curve[h] / 24.0
	for fid in s["facilities"]:
		var f := NearbyFacility.find(fid)
		var w: Array = f["hour_weights"]
		var total := 0.0
		for x in w:
			total += float(x)
		if total <= 0.0:
			continue
		for h in 24:
			out[h] += float(f["visitors_per_day"]) * float(w[h]) / total
	return out
