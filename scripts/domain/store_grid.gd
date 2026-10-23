class_name StoreGrid
extends RefCounted
## Store tiles + FixtureInstances (placement data, separate from FixtureType masters).
## Occupancy/rotation follow 10_TEST_VECTORS §A. Path/access rules arrive with #7.

const ROTATIONS := [0, 1, 2, 3]

var store_id: String = ""
var width: int = 0
var height: int = 0
var entrance_tiles: Array[Vector2i] = []
var instances: Dictionary = {}
var load_errors: Array[String] = []
var _occupancy: Dictionary = {}


static func create(id: String, w: int, h: int, entrances: Array[Vector2i]) -> StoreGrid:
	var g := StoreGrid.new()
	g.store_id = id
	g.width = w
	g.height = h
	g.entrance_tiles = entrances
	return g


## Cells covered by a footprint at (x,y) with rotation 0..3. r1/r3 swap w and h.
static func footprint_cells(footprint: Dictionary, x: int, y: int, rotation: int) -> Array[Vector2i]:
	var w := int(footprint["w"])
	var h := int(footprint["h"])
	if rotation == 1 or rotation == 3:
		var t := w
		w = h
		h = t
	var cells: Array[Vector2i] = []
	for dx in w:
		for dy in h:
			cells.append(Vector2i(x + dx, y + dy))
	return cells


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func occupant_at(c: Vector2i) -> String:
	return _occupancy.get(c, "")


## All-or-nothing: returns &"OK" or the failure code; the grid is untouched on failure.
func add_instance(inst: Dictionary, fixtures: FixtureCatalog) -> StringName:
	for k in ["instance_id", "type_id", "x", "y", "rotation", "enabled"]:
		if not inst.has(k):
			return &"INVALID_OPERATION"
	if not JsonCheck.is_nonempty_string(inst["instance_id"]) or not JsonCheck.is_nonempty_string(inst["type_id"]):
		return &"INVALID_OPERATION"
	if not JsonCheck.is_int(inst["x"]) or not JsonCheck.is_int(inst["y"]) or not JsonCheck.is_int(inst["rotation"]):
		return &"INVALID_OPERATION"
	if typeof(inst["enabled"]) != TYPE_BOOL or not ROTATIONS.has(int(inst["rotation"])):
		return &"INVALID_OPERATION"
	if instances.has(inst["instance_id"]) or not fixtures.has_type(inst["type_id"]):
		return &"INVALID_OPERATION"
	var cells := footprint_cells(fixtures.get_type(inst["type_id"])["footprint"], int(inst["x"]), int(inst["y"]), int(inst["rotation"]))
	for c in cells:
		if not in_bounds(c):
			return &"OUT_OF_BOUNDS"
	for c in cells:
		if _occupancy.has(c):
			return &"OCCUPIED"
	var rec := {
		"instance_id": inst["instance_id"], "type_id": inst["type_id"],
		"x": int(inst["x"]), "y": int(inst["y"]), "rotation": int(inst["rotation"]),
		"enabled": inst["enabled"],
	}
	instances[rec["instance_id"]] = rec
	for c in cells:
		_occupancy[c] = rec["instance_id"]
	return &"OK"


func remove_instance(instance_id: String) -> bool:
	if not instances.has(instance_id):
		return false
	for c in _occupancy.keys():
		if _occupancy[c] == instance_id:
			_occupancy.erase(c)
	instances.erase(instance_id)
	return true


## Save-format sections `store` and `fixture_instances` (savegame.schema.json).
func to_save() -> Dictionary:
	var ids := instances.keys()
	ids.sort()
	var list: Array = []
	for id in ids:
		list.append(instances[id].duplicate())
	var entrances: Array = []
	for t in entrance_tiles:
		entrances.append({"x": t.x, "y": t.y})
	return {
		"store": {"store_id": store_id, "width": width, "height": height, "entrance_tiles": entrances},
		"fixture_instances": list,
	}


## Rebuilds a grid from saved sections. Any invalid instance is reported in `load_errors`
## (never silently dropped), so callers must check is_valid() before using the grid.
static func from_save(store, instance_list, fixtures: FixtureCatalog) -> StoreGrid:
	var g := StoreGrid.new()
	if typeof(store) != TYPE_DICTIONARY or typeof(instance_list) != TYPE_ARRAY:
		g.load_errors.append("$: invalid_store_sections")
		return g
	for k in ["store_id", "width", "height", "entrance_tiles"]:
		if not store.has(k):
			g.load_errors.append("store.%s: missing_field" % k)
	if not g.load_errors.is_empty():
		return g
	if not JsonCheck.is_int(store["width"]) or not JsonCheck.is_int(store["height"]) \
			or int(store["width"]) < 1 or int(store["height"]) < 1 \
			or not JsonCheck.is_nonempty_string(store["store_id"]) or typeof(store["entrance_tiles"]) != TYPE_ARRAY \
			or store["entrance_tiles"].is_empty():
		g.load_errors.append("store: invalid")
		return g
	g.store_id = store["store_id"]
	g.width = int(store["width"])
	g.height = int(store["height"])
	for t in store["entrance_tiles"]:
		if typeof(t) != TYPE_DICTIONARY or not t.has("x") or not t.has("y") \
				or not JsonCheck.is_int(t["x"]) or not JsonCheck.is_int(t["y"]):
			g.load_errors.append("store.entrance_tiles: invalid")
			continue
		var c := Vector2i(int(t["x"]), int(t["y"]))
		if not g.in_bounds(c):
			g.load_errors.append("store.entrance_tiles: out_of_bounds")
		g.entrance_tiles.append(c)
	for i in instance_list.size():
		if typeof(instance_list[i]) != TYPE_DICTIONARY:
			g.load_errors.append("fixture_instances[%d]: not_object" % i)
			continue
		var code := g.add_instance(instance_list[i], fixtures)
		if code != &"OK":
			g.load_errors.append("fixture_instances[%d]: %s" % [i, code])
	return g


func is_valid() -> bool:
	return load_errors.is_empty()
