class_name FixtureCatalog
extends RefCounted
## FixtureType master (fixture_definition.schema.json + semantic checks from
## docs/examples/README.md: capacity = sum(slot capacities), dimensions <= footprint - 0.08 m).

const SUPPORTED_SCHEMA_VERSION := 1
const EDGES: Array[String] = ["N", "E", "S", "W"]
const FOOTPRINT_MARGIN_M := 0.08
const EPS := 1e-9
const REQUIRED := [
	"schema_version", "type_id", "display_name", "footprint", "dimensions_m", "placement_cost_yen",
	"electricity_cost_yen_per_day", "capacity_units", "allowed_categories", "access_edges",
	"visual_id", "shelf_slots",
]

var types: Dictionary = {}
var errors: Array[String] = []
var future_schema_version: bool = false


static func from_json_text(text: String) -> FixtureCatalog:
	var cat := FixtureCatalog.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		cat.errors.append("$: invalid_json")
		return cat
	return from_array(json.data)


static func from_array(data) -> FixtureCatalog:
	var cat := FixtureCatalog.new()
	if typeof(data) != TYPE_ARRAY:
		cat.errors.append("$: root_not_array")
		return cat
	for i in data.size():
		cat._add_entry(data[i], "$[%d]" % i)
	return cat


func is_valid() -> bool:
	return errors.is_empty()


func has_type(type_id: String) -> bool:
	return types.has(type_id)


func get_type(type_id: String) -> Dictionary:
	return types.get(type_id, {})


## Can `slot_id` of fixture `type_id` hold this SKU? Category must be allowed and one unit must fit.
func slot_accepts(type_id: String, slot_id: String, sku: Dictionary) -> bool:
	for slot in get_type(type_id).get("shelf_slots", []):
		if slot["slot_id"] == slot_id:
			return slot["allowed_categories"].has(sku["category"]) and int(slot["capacity_units"]) >= int(sku["slot_units"])
	return false


## Cross-reference check: every product category must be storable in some fixture
## slot large enough for the product's slot_units.
func product_errors(products: ProductCatalog) -> Array[String]:
	var errs: Array[String] = []
	for sku_id in products.skus:
		var p: Dictionary = products.skus[sku_id]
		var fits := false
		for t in types.values():
			for slot in t["shelf_slots"]:
				if slot["allowed_categories"].has(p["category"]) and int(slot["capacity_units"]) >= int(p["slot_units"]):
					fits = true
		if not fits:
			errs.append("sku %s: no_compatible_fixture_slot" % sku_id)
	return errs


func _check_categories(v, path: String, errs: Array[String], allow_empty: bool) -> void:
	if typeof(v) != TYPE_ARRAY:
		errs.append("%s: not_array" % path)
		return
	if v.is_empty() and not allow_empty:
		errs.append("%s: empty" % path)
	var seen := {}
	for c in v:
		if not ProductCatalog.CATEGORIES.has(c):
			errs.append("%s: unknown_category" % path)
		elif seen.has(c):
			errs.append("%s: duplicate_category" % path)
		seen[c] = true


func _nonneg_int(e: Dictionary, key: String, path: String, errs: Array[String]) -> void:
	if not e.has(key):
		return
	if not JsonCheck.is_int(e[key]):
		errs.append("%s.%s: not_integer" % [path, key])
	elif int(e[key]) < 0:
		errs.append("%s.%s: negative" % [path, key])


func _add_entry(e, path: String) -> void:
	if typeof(e) != TYPE_DICTIONARY:
		errors.append("%s: not_object" % path)
		return
	var errs := JsonCheck.key_errors(e, REQUIRED, ["register_queue_max_tiles", "staff_capacity", "min_store_width"], path)
	if e.has("schema_version"):
		if not JsonCheck.is_int(e["schema_version"]):
			errs.append("%s.schema_version: not_integer" % path)
		elif int(e["schema_version"]) > SUPPORTED_SCHEMA_VERSION:
			future_schema_version = true
			errs.append("%s.schema_version: unsupported_schema_version" % path)
		elif int(e["schema_version"]) != SUPPORTED_SCHEMA_VERSION:
			errs.append("%s.schema_version: invalid_schema_version" % path)
	if e.has("type_id") and not JsonCheck.is_id(e["type_id"]):
		errs.append("%s.type_id: invalid_id" % path)
	if e.has("display_name") and not JsonCheck.is_nonempty_string(e["display_name"]):
		errs.append("%s.display_name: empty" % path)
	if e.has("visual_id") and not JsonCheck.is_id(e["visual_id"]):
		errs.append("%s.visual_id: invalid_id" % path)
	_nonneg_int(e, "placement_cost_yen", path, errs)
	_nonneg_int(e, "electricity_cost_yen_per_day", path, errs)
	_nonneg_int(e, "capacity_units", path, errs)
	_nonneg_int(e, "register_queue_max_tiles", path, errs)
	_nonneg_int(e, "staff_capacity", path, errs)    # #143: a staff room and how many staff it allows
	_nonneg_int(e, "min_store_width", path, errs)   # #143: the smallest store (width in tiles) it fits

	var fw := 0
	var fh := 0
	var footprint_ok := false
	if e.has("footprint"):
		var f = e["footprint"]
		if typeof(f) != TYPE_DICTIONARY or not f.has("w") or not f.has("h") \
				or not JsonCheck.is_int(f["w"]) or not JsonCheck.is_int(f["h"]) \
				or int(f["w"]) < 1 or int(f["h"]) < 1:
			errs.append("%s.footprint: invalid" % path)
		else:
			fw = int(f["w"])
			fh = int(f["h"])
			footprint_ok = true
	if e.has("dimensions_m"):
		var d = e["dimensions_m"]
		var dims_ok := typeof(d) == TYPE_DICTIONARY
		if dims_ok:
			for k in ["width", "depth", "height"]:
				if not d.has(k) or not JsonCheck.is_number(d[k]) or float(d[k]) <= 0.0:
					dims_ok = false
		if not dims_ok:
			errs.append("%s.dimensions_m: invalid" % path)
		elif footprint_ok:
			if float(d["width"]) > fw - FOOTPRINT_MARGIN_M + EPS or float(d["depth"]) > fh - FOOTPRINT_MARGIN_M + EPS:
				errs.append("%s.dimensions_m: exceeds_footprint" % path)
	if e.has("allowed_categories"):
		_check_categories(e["allowed_categories"], path + ".allowed_categories", errs, true)
	if e.has("access_edges"):
		if typeof(e["access_edges"]) != TYPE_ARRAY:
			errs.append("%s.access_edges: not_array" % path)
		else:
			var seen := {}
			for edge in e["access_edges"]:
				if not EDGES.has(edge):
					errs.append("%s.access_edges: unknown_edge" % path)
				elif seen.has(edge):
					errs.append("%s.access_edges: duplicate_edge" % path)
				seen[edge] = true
	if e.has("shelf_slots"):
		_check_slots(e, path, errs)
	if errs.is_empty() and types.has(e["type_id"]):
		errs.append("%s.type_id: duplicate_id" % path)
	errors.append_array(errs)
	if errs.is_empty():
		types[e["type_id"]] = _normalize(e)


func _check_slots(e: Dictionary, path: String, errs: Array[String]) -> void:
	if typeof(e["shelf_slots"]) != TYPE_ARRAY:
		errs.append("%s.shelf_slots: not_array" % path)
		return
	var ids := {}
	var total := 0
	var slots_ok := true
	for j in e["shelf_slots"].size():
		var s = e["shelf_slots"][j]
		var sp := "%s.shelf_slots[%d]" % [path, j]
		if typeof(s) != TYPE_DICTIONARY:
			errs.append("%s: not_object" % sp)
			slots_ok = false
			continue
		var before := errs.size()
		errs.append_array(JsonCheck.key_errors(s, ["slot_id", "capacity_units", "allowed_categories"], [], sp))
		if s.has("slot_id"):
			if not JsonCheck.is_id(s["slot_id"]):
				errs.append("%s.slot_id: invalid_id" % sp)
			elif ids.has(s["slot_id"]):
				errs.append("%s.slot_id: duplicate_id" % sp)
			ids[s["slot_id"]] = true
		if s.has("capacity_units"):
			if not JsonCheck.is_int(s["capacity_units"]):
				errs.append("%s.capacity_units: not_integer" % sp)
			elif int(s["capacity_units"]) < 1:
				errs.append("%s.capacity_units: below_minimum" % sp)
			else:
				total += int(s["capacity_units"])
		if s.has("allowed_categories"):
			_check_categories(s["allowed_categories"], sp + ".allowed_categories", errs, false)
			if typeof(s["allowed_categories"]) == TYPE_ARRAY and typeof(e.get("allowed_categories")) == TYPE_ARRAY:
				for c in s["allowed_categories"]:
					if not e["allowed_categories"].has(c):
						errs.append("%s.allowed_categories: not_in_fixture_categories" % sp)
		if errs.size() > before:
			slots_ok = false
	if slots_ok and JsonCheck.is_int(e.get("capacity_units")) and int(e["capacity_units"]) != total:
		errs.append("%s.capacity_units: not_sum_of_slots" % path)


func _normalize(e: Dictionary) -> Dictionary:
	var n: Dictionary = e.duplicate(true)
	for k in ["schema_version", "placement_cost_yen", "electricity_cost_yen_per_day", "capacity_units"]:
		n[k] = int(n[k])
	n["footprint"] = {"w": int(e["footprint"]["w"]), "h": int(e["footprint"]["h"])}
	for slot in n["shelf_slots"]:
		slot["capacity_units"] = int(slot["capacity_units"])
	if n.has("register_queue_max_tiles"):
		n["register_queue_max_tiles"] = int(n["register_queue_max_tiles"])
	return n
