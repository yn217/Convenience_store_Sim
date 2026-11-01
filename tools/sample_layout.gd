extends RefCounted
## Sample/demo/bench layout for tools/capture_screen.gd and tools/perf_bench.gd (not gameplay data).
## Reads data/layouts/sample_store_v1.json; falls back to FALLBACK_PLAN when the file is missing or unreadable.

const LAYOUT_PATH := "res://data/layouts/sample_store_v1.json"

## The earlier hard-coded bench layout, kept as the fallback. Each entry: [type_id, x, y, rotation].
const FALLBACK_PLAN := [
	["register_basic", 13, 5, 0], ["shelf_general", 3, 2, 0], ["shelf_onigiri", 3, 5, 0], ["shelf_noodle", 3, 8, 0],
	["shelf_bread", 6, 2, 0], ["shelf_snack", 6, 5, 0], ["shelf_general", 6, 8, 0], ["fridge_drink", 9, 2, 0],
	["fridge_dessert", 9, 5, 0], ["freezer_ice", 11, 9, 0], ["warmer_oden", 13, 2, 0], ["shelf_general", 1, 11, 1],
	["shelf_onigiri", 4, 11, 1], ["shelf_snack", 12, 11, 1], ["shelf_bread", 10, 7, 1], ["shelf_noodle", 14, 9, 1],
	["shelf_general", 14, 11, 1], ["fridge_drink", 1, 9, 1], ["shelf_snack", 12, 7, 1], ["fridge_dessert", 8, 9, 1],
]


## Placements as [type_id, x, y, rotation] in file order.
static func placements() -> Array:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return FALLBACK_PLAN.duplicate(true)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("placements"):
		return FALLBACK_PLAN.duplicate(true)
	var out := []
	for p in parsed["placements"]:
		out.append([String(p["type_id"]), int(p["x"]), int(p["y"]), int(p["rotation"])])
	return out
