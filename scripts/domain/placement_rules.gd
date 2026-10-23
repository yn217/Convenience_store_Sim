class_name PlacementRules
extends RefCounted
## Placement validation (02 §D, 12 §3). Pure and read-only: it never mutates the grid, so
## previews cannot spend cash or reserve space. Every fixture must keep a free access tile that
## customers can walk to from the entrance (PathService), a register must keep a queue slot, and
## a placement may not take either away from another fixture (AccessService).

const EDGE_ORDER: Array[String] = ["N", "E", "S", "W"]


## Access edge after rotating the fixture clockwise by `rotation` quarter turns (N -> E -> S -> W).
static func rotate_edge(edge: String, rotation: int) -> String:
	return EDGE_ORDER[(EDGE_ORDER.find(edge) + rotation) % 4]


## Cells in front of each (rotated) access edge, before any walkability filtering.
static func access_candidates(def: Dictionary, x: int, y: int, rotation: int) -> Array[Vector2i]:
	var cells := StoreGrid.footprint_cells(def["footprint"], x, y, rotation)
	var min_x := x
	var min_y := y
	var max_x := x
	var max_y := y
	for c in cells:
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)
	var out: Array[Vector2i] = []
	for edge in def["access_edges"]:
		match rotate_edge(edge, rotation):
			"N":
				for cx in range(min_x, max_x + 1):
					out.append(Vector2i(cx, min_y - 1))
			"E":
				for cy in range(min_y, max_y + 1):
					out.append(Vector2i(max_x + 1, cy))
			"S":
				for cx in range(min_x, max_x + 1):
					out.append(Vector2i(cx, max_y + 1))
			"W":
				for cy in range(min_y, max_y + 1):
					out.append(Vector2i(min_x - 1, cy))
	return out


## Candidate access cells that are inside the store and not covered by `blocked`.
static func walkable_access(grid: StoreGrid, candidates: Array[Vector2i], blocked: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in candidates:
		if grid.in_bounds(c) and not blocked.has(c):
			out.append(c)
	return out


static func _failure(code: StringName, message: StringName, cells: Array[Vector2i]) -> PlacementResult:
	var r := PlacementResult.new()
	r.code = code
	r.message_key = message
	r.cells = cells
	return r


## `ignore_id` is the fixture being moved: its old cells count as free, its new cells as taken.
## `charge` adds the catalog price for new placements (moves cost nothing).
static func validate(grid: StoreGrid, fixtures: FixtureCatalog, type_id: String, x: int, y: int, rotation: int, cash_yen: int, ignore_id: String = "", charge: bool = true) -> PlacementResult:
	if not fixtures.has_type(type_id) or not StoreGrid.ROTATIONS.has(rotation):
		return _failure(&"INVALID_OPERATION", &"unknown_type_or_rotation", [])
	var def := fixtures.get_type(type_id)
	var cells := StoreGrid.footprint_cells(def["footprint"], x, y, rotation)
	for c in cells:
		if not grid.in_bounds(c):
			return _failure(&"OUT_OF_BOUNDS", &"outside_store", cells)
	for c in cells:
		if grid.is_blocked(c, ignore_id):
			return _failure(&"OCCUPIED", &"cell_occupied", cells)
	for c in cells:
		if grid.entrance_tiles.has(c):
			return _failure(&"ENTRANCE_BLOCKED", &"blocks_entrance", cells)
	var blocked := grid.blocked_cells(ignore_id)
	for c in cells:
		blocked[c] = true
	var reach := PathService.distances(grid, blocked)
	var is_register := AccessService.is_register(def)
	var fail_code: StringName = &"REGISTER_BLOCKED" if is_register else &"UNREACHABLE_ACCESS"
	if not def["access_edges"].is_empty():
		if walkable_access(grid, access_candidates(def, x, y, rotation), blocked).is_empty():
			return _failure(fail_code, &"no_access_tile", cells)
		if AccessService.reachable_access(grid, def, x, y, rotation, reach).is_empty():
			return _failure(fail_code, &"access_unreachable", cells)
	var plan := {}
	if is_register:
		plan = AccessService.register_plan(grid, def, x, y, rotation, blocked, reach)
		if int(plan["slots"]) < 1:
			return _failure(&"REGISTER_BLOCKED", &"no_queue_space", cells)
	var verdict := _other_fixture_verdict(grid, fixtures, blocked, reach, ignore_id)
	if verdict != {}:
		return _failure(verdict["code"], verdict["message"], cells)
	var access := AccessService.reachable_access(grid, def, x, y, rotation, reach)
	var cost := int(def["placement_cost_yen"]) if charge else 0
	if cost > cash_yen:
		return _failure(&"INSUFFICIENT_CASH", &"not_enough_cash", cells)
	var r := PlacementResult.new()
	r.ok = true
	r.code = &"OK"
	r.cells = cells
	r.access_cells = access
	if is_register:
		r.queue_cells = plan["queue_cells"]
	r.cost_yen = cost
	return r


## A placement may not cut any other fixture off the entrance, take away its last access
## tile, or (for a register) shrink its queue to nothing. Returns {} when nothing is lost.
static func _other_fixture_verdict(grid: StoreGrid, fixtures: FixtureCatalog, blocked: Dictionary, reach: Dictionary, ignore_id: String) -> Dictionary:
	var before_blocked := grid.blocked_cells(ignore_id)
	var before_reach := PathService.distances(grid, before_blocked)
	var ids := grid.instances.keys()
	ids.sort()
	for id in ids:
		if id == ignore_id:
			continue
		var inst: Dictionary = grid.instances[id]
		var def := fixtures.get_type(inst["type_id"])
		if def["access_edges"].is_empty():
			continue
		var is_register := AccessService.is_register(def)
		var code: StringName = &"REGISTER_BLOCKED" if is_register else &"UNREACHABLE_ACCESS"
		var had := AccessService.reachable_access(grid, def, inst["x"], inst["y"], inst["rotation"], before_reach)
		if had.is_empty():
			continue
		if AccessService.reachable_access(grid, def, inst["x"], inst["y"], inst["rotation"], reach).is_empty():
			return {"code": code, "message": &"blocks_other_access"}
		if is_register:
			var slots_before := int(AccessService.register_plan(grid, def, inst["x"], inst["y"], inst["rotation"], before_blocked, before_reach)["slots"])
			var slots_after := int(AccessService.register_plan(grid, def, inst["x"], inst["y"], inst["rotation"], blocked, reach)["slots"])
			if slots_before > 0 and slots_after == 0:
				return {"code": code, "message": &"blocks_register_queue"}
	return {}
