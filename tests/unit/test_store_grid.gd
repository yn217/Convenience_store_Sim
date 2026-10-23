extends RefCounted
## StoreGrid placement data (Issue #3) + 10_TEST_VECTORS §A occupancy goldens + save round trip.

const FIXTURES := "res://data/fixtures/mvp_v1.json"
const SAVE_SAMPLE := "res://tests/data/empty_store.savegame.json"


func _fixtures() -> FixtureCatalog:
	return FixtureCatalog.from_json_text(FileAccess.get_file_as_string(FIXTURES))


func _grid() -> StoreGrid:
	var entrances: Array[Vector2i] = [Vector2i(0, 5), Vector2i(0, 6)]
	return StoreGrid.create("store_001", 16, 12, entrances)


func _inst(id: String, type_id: String, x: int, y: int, r: int = 0) -> Dictionary:
	return {"instance_id": id, "type_id": type_id, "x": x, "y": y, "rotation": r, "enabled": true}


func test_occupancy_rotation_goldens(t, _tree) -> void:
	var fp := {"w": 1, "h": 2}
	var r0 := StoreGrid.footprint_cells(fp, 4, 5, 0)
	var r1 := StoreGrid.footprint_cells(fp, 4, 5, 1)
	t.eq(r0, [Vector2i(4, 5), Vector2i(4, 6)] as Array[Vector2i], "r0")
	t.eq(r1, [Vector2i(4, 5), Vector2i(5, 5)] as Array[Vector2i], "r1")
	t.eq(StoreGrid.footprint_cells(fp, 4, 5, 2), r0, "r2 same cells as r0")
	t.eq(StoreGrid.footprint_cells(fp, 4, 5, 3), r1, "r3 same cells as r1")
	t.eq(StoreGrid.footprint_cells({"w": 2, "h": 2}, 3, 3, 1).size(), 4, "2x2 stays 4 cells")


func test_place_and_reject_table(t, _tree) -> void:
	var fx := _fixtures()
	var g := _grid()
	t.eq(g.add_instance(_inst("fx1", "shelf_general", 4, 5), fx), &"OK")
	t.eq(g.occupant_at(Vector2i(4, 6)), "fx1", "second cell occupied")
	var cases := [
		["overlap", _inst("fx2", "shelf_general", 4, 6), &"OCCUPIED"],
		["duplicate id", _inst("fx1", "shelf_general", 8, 8), &"INVALID_OPERATION"],
		["negative x", _inst("fx3", "shelf_general", -1, 0), &"OUT_OF_BOUNDS"],
		["right edge", _inst("fx4", "shelf_general", 16, 0), &"OUT_OF_BOUNDS"],
		["bottom edge 1x2", _inst("fx5", "shelf_general", 0, 11), &"OUT_OF_BOUNDS"],
		["rotated past edge", _inst("fx6", "shelf_general", 15, 0, 1), &"OUT_OF_BOUNDS"],
		["unknown type", _inst("fx7", "vending_machine", 8, 8), &"INVALID_OPERATION"],
		["bad rotation", _inst("fx8", "shelf_general", 8, 8, 4), &"INVALID_OPERATION"],
		["fractional x", {"instance_id": "fx9", "type_id": "shelf_general", "x": 1.5, "y": 1, "rotation": 0, "enabled": true}, &"INVALID_OPERATION"],
	]
	for c in cases:
		t.eq(g.add_instance(c[1], fx), c[2], c[0])
	t.eq(g.instances.size(), 1, "failed placements leave the grid untouched")
	t.ok(g.remove_instance("fx1"), "remove")
	t.eq(g.occupant_at(Vector2i(4, 5)), "", "cells freed")
	t.eq(g.add_instance(_inst("fx2", "shelf_general", 4, 6), fx), &"OK", "space reusable")


func test_master_and_instance_are_separate(t, _tree) -> void:
	var fx := _fixtures()
	var g := _grid()
	g.add_instance(_inst("fx1", "register_basic", 2, 2), fx)
	t.eq(g.instances["fx1"].keys().size(), 6, "instance holds placement only")
	t.ok(not g.instances["fx1"].has("placement_cost_yen"), "no master data copied into instance")


func test_save_round_trip(t, _tree) -> void:
	var fx := _fixtures()
	var g := _grid()
	g.add_instance(_inst("b_fridge", "fridge_drink", 6, 2, 1), fx)
	g.add_instance(_inst("a_register", "register_basic", 2, 8), fx)
	g.add_instance(_inst("c_ice", "freezer_ice", 10, 6), fx)
	var saved := g.to_save()
	t.eq(saved["fixture_instances"][0]["instance_id"], "a_register", "sorted by id for stable output")
	var restored := StoreGrid.from_save(saved["store"], JSON.parse_string(JSON.stringify(saved["fixture_instances"])), fx)
	t.ok(restored.is_valid(), "restored valid: " + str(restored.load_errors))
	t.eq(restored.to_save(), saved, "save -> load -> save is identical")
	t.eq(restored.occupant_at(Vector2i(7, 2)), "b_fridge", "occupancy rebuilt with rotation")


func test_load_rejects_bad_saved_instances(t, _tree) -> void:
	var fx := _fixtures()
	var store := {"store_id": "s", "width": 16, "height": 12, "entrance_tiles": [{"x": 0, "y": 5}]}
	var bad := [_inst("a", "shelf_general", 0, 0), _inst("a", "shelf_general", 5, 5), _inst("b", "shelf_general", 0, 1), _inst("c", "nope", 9, 9)]
	var g := StoreGrid.from_save(store, bad, fx)
	t.ok(not g.is_valid(), "invalid saves are reported, not silently dropped")
	t.eq(g.load_errors.size(), 3, "duplicate id, overlap, unknown type")
	t.ok(not StoreGrid.from_save({"store_id": "s"}, [], fx).is_valid(), "missing store fields")
	var off := {"store_id": "s", "width": 16, "height": 12, "entrance_tiles": [{"x": 99, "y": 0}]}
	t.ok(not StoreGrid.from_save(off, [], fx).is_valid(), "entrance outside the store")


func test_empty_store_sample_save_is_consistent_with_domain(t, _tree) -> void:
	var save = JSON.parse_string(FileAccess.get_file_as_string(SAVE_SAMPLE))
	var fx := _fixtures()
	var g := StoreGrid.from_save(save["store"], save["fixture_instances"], fx)
	t.ok(g.is_valid(), "sample store loads: " + str(g.load_errors))
	t.eq(g.width, 16)
	t.eq(g.height, 12)
	t.eq(g.entrance_tiles, [Vector2i(0, 5), Vector2i(0, 6)] as Array[Vector2i], "fixed west entrance")
	t.eq(save["business_state"], String(GameState.SETUP), "business_state matches GameState")
	t.ok([&"SETUP", &"OPEN", &"CLOSING", &"PAYMENT_BLOCKED"].has(StringName(save["business_state"])), "known state")
	t.eq(save["applied_command_ids"], [], "no commands applied in an empty save")
	for k in save["rng_states"]:
		var v: int = int(save["rng_states"][k])
		t.ok(v >= 0 and v < Lcg32.MODULUS, "rng %s is a 32bit state" % k)
	t.eq(int(save["rng_states"]["arrivals"]), 1234)
