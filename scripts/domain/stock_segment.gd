class_name StockSegment
extends RefCounted
## StockLot segment validation (inventory_segments in savegame.schema.json, 03 §slot capacity).
## A lot split across locations is one segment per location; this file only validates,
## it does not mutate stock (Inventory transactions arrive with #11).

const REQUIRED := [
	"segment_id", "lot_id", "sku_id", "unit_cost_yen", "expires_at_sec",
	"physical_qty", "reserved_qty", "location",
]


## Per-segment structural/semantic errors. `grid` is optional; with it, FIXTURE locations
## are resolved against placed instances and their slot definitions.
static func segment_errors(seg, products: ProductCatalog, fixtures: FixtureCatalog, grid: StoreGrid, path: String) -> Array[String]:
	var errs: Array[String] = []
	if typeof(seg) != TYPE_DICTIONARY:
		errs.append("%s: not_object" % path)
		return errs
	errs.append_array(JsonCheck.key_errors(seg, REQUIRED, [], path))
	for k in ["segment_id", "lot_id", "sku_id"]:
		if seg.has(k) and not JsonCheck.is_nonempty_string(seg[k]):
			errs.append("%s.%s: empty" % [path, k])
	if seg.has("sku_id") and JsonCheck.is_nonempty_string(seg["sku_id"]) and not products.has_sku(seg["sku_id"]):
		errs.append("%s.sku_id: unknown_sku" % path)
	for k in ["unit_cost_yen", "physical_qty", "reserved_qty"]:
		if seg.has(k):
			if not JsonCheck.is_int(seg[k]):
				errs.append("%s.%s: not_integer" % [path, k])
			elif int(seg[k]) < 0:
				errs.append("%s.%s: negative" % [path, k])
	if seg.has("expires_at_sec") and seg["expires_at_sec"] != null:
		if not JsonCheck.is_int(seg["expires_at_sec"]):
			errs.append("%s.expires_at_sec: not_integer" % path)
		elif int(seg["expires_at_sec"]) < 0:
			errs.append("%s.expires_at_sec: negative" % path)
	if seg.has("physical_qty") and seg.has("reserved_qty") \
			and JsonCheck.is_int(seg["physical_qty"]) and JsonCheck.is_int(seg["reserved_qty"]) \
			and int(seg["reserved_qty"]) > int(seg["physical_qty"]):
		errs.append("%s.reserved_qty: exceeds_physical" % path)
	if seg.has("location"):
		_location_errors(seg, products, fixtures, grid, path, errs)
	return errs


static func _location_errors(seg: Dictionary, products: ProductCatalog, fixtures: FixtureCatalog, grid: StoreGrid, path: String, errs: Array[String]) -> void:
	var loc = seg["location"]
	if typeof(loc) != TYPE_DICTIONARY or not loc.has("kind"):
		errs.append("%s.location: invalid" % path)
		return
	if loc["kind"] == "BACKROOM":
		if loc.has("fixture_id") or loc.has("slot_id"):
			errs.append("%s.location: backroom_has_slot" % path)
	elif loc["kind"] == "FIXTURE" or loc["kind"] == "OVEN":   # OVEN: a lot baking for that slot (#130), with ready_at_sec
		if loc["kind"] == "OVEN" and not JsonCheck.is_int(loc.get("ready_at_sec")):
			errs.append("%s.location.ready_at_sec: invalid" % path)
		if not JsonCheck.is_nonempty_string(loc.get("fixture_id")) or not JsonCheck.is_nonempty_string(loc.get("slot_id")):
			errs.append("%s.location: fixture_slot_missing" % path)
		elif grid != null:
			if not grid.instances.has(loc["fixture_id"]):
				errs.append("%s.location.fixture_id: unknown_fixture_instance" % path)
				return
			var type_def := fixtures.get_type(grid.instances[loc["fixture_id"]]["type_id"])
			var slot := {}
			for s in type_def.get("shelf_slots", []):
				if s["slot_id"] == loc["slot_id"]:
					slot = s
			if slot.is_empty():
				errs.append("%s.location.slot_id: unknown_slot" % path)
			elif products.has_sku(str(seg.get("sku_id", ""))) \
					and not slot["allowed_categories"].has(products.get_sku(seg["sku_id"])["category"]):
				errs.append("%s.location: incompatible_category" % path)
	else:
		errs.append("%s.location.kind: unknown_kind" % path)


## Whole-list checks: duplicate segment IDs, 1 SKU per slot, slot and fixture capacity
## (sum(slot_units * physical_qty) <= capacity).
static func list_errors(segments, products: ProductCatalog, fixtures: FixtureCatalog, grid: StoreGrid) -> Array[String]:
	var errs: Array[String] = []
	if typeof(segments) != TYPE_ARRAY:
		errs.append("$: not_array")
		return errs
	var ids := {}
	var slot_units := {}
	var slot_sku := {}
	for i in segments.size():
		var path := "inventory_segments[%d]" % i
		var seg_errs := segment_errors(segments[i], products, fixtures, grid, path)
		errs.append_array(seg_errs)
		if not seg_errs.is_empty():
			continue
		var seg: Dictionary = segments[i]
		if ids.has(seg["segment_id"]):
			errs.append("%s.segment_id: duplicate_id" % path)
		ids[seg["segment_id"]] = true
		var loc: Dictionary = seg["location"]
		if loc["kind"] == "FIXTURE" or loc["kind"] == "OVEN":
			var key := "%s/%s" % [loc["fixture_id"], loc["slot_id"]]
			if slot_sku.has(key) and slot_sku[key] != seg["sku_id"]:
				errs.append("%s.location: slot_holds_multiple_skus" % path)
			slot_sku[key] = seg["sku_id"]
			slot_units[key] = int(slot_units.get(key, 0)) + int(products.get_sku(seg["sku_id"])["slot_units"]) * int(seg["physical_qty"])
	if grid != null:
		var fixture_total := {}
		for key in slot_units:
			var parts: PackedStringArray = key.split("/")
			var type_def := fixtures.get_type(grid.instances[parts[0]]["type_id"])
			for s in type_def["shelf_slots"]:
				if s["slot_id"] == parts[1] and slot_units[key] > int(s["capacity_units"]):
					errs.append("%s: slot_capacity_exceeded" % key)
			fixture_total[parts[0]] = int(fixture_total.get(parts[0], 0)) + slot_units[key]
		for fid in fixture_total:
			if fixture_total[fid] > int(fixtures.get_type(grid.instances[fid]["type_id"])["capacity_units"]):
				errs.append("%s: fixture_capacity_exceeded" % fid)
	return errs
