class_name EntranceRules
extends RefCounted
## Moving the entrance (issue #121). The entrance is two tiles side by side on one outer wall, never on a corner.
## A move is refused when a fixture stands there or when, with the new door, a fixture would lose its last
## reachable access tile or a register its whole queue (the same rules as placing a fixture). The facade, floor,
## outside, camera and the customers' and staff's ways in all follow grid.entrance_tiles (#110).


## The two tiles of an entrance starting at (x, y) along its wall (east / south from it); [] when (x, y) is not on
## an outer wall or the pair would touch a corner.
static func tiles_at(width: int, height: int, x: int, y: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if y == 0 or y == height - 1:
		if x >= 1 and x + 1 <= width - 2:
			out = [Vector2i(x, y), Vector2i(x + 1, y)]
	elif x == 0 or x == width - 1:
		if y >= 1 and y + 1 <= height - 2:
			out = [Vector2i(x, y), Vector2i(x, y + 1)]
	return out


## Every place the entrance could go (start tiles), wall by wall: south, east, north, west.
static func candidates(width: int, height: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(1, width - 2):
		out.append(Vector2i(x, height - 1))
	for y in range(1, height - 2):
		out.append(Vector2i(width - 1, y))
	for x in range(1, width - 2):
		out.append(Vector2i(x, 0))
	for y in range(1, height - 2):
		out.append(Vector2i(0, y))
	return out


## Japanese name of a place: 手前の壁 / 右の壁 / 奥の壁 / 左の壁 and the columns or rows (1-based).
static func label(width: int, height: int, start: Vector2i) -> String:
	if start.y == height - 1:
		return "手前の壁 %d〜%d列目" % [start.x + 1, start.x + 2]
	if start.y == 0:
		return "奥の壁 %d〜%d列目" % [start.x + 1, start.x + 2]
	if start.x == width - 1:
		return "右の壁 %d〜%d行目" % [start.y + 1, start.y + 2]
	return "左の壁 %d〜%d行目" % [start.y + 1, start.y + 2]


## "" when the entrance may move to `tiles`, else the reason.
static func check(grid: StoreGrid, fixtures: FixtureCatalog, tiles: Array[Vector2i]) -> String:
	if tiles.is_empty():
		return "entrance_not_on_wall"
	if tiles == grid.entrance_tiles:
		return "entrance_unchanged"
	var blocked := grid.blocked_cells()
	for t in tiles:
		if blocked.has(t):
			return "entrance_blocked"
	var moved := StoreGrid.create(grid.store_id, grid.width, grid.height, tiles.duplicate())
	var ids := grid.instances.keys()
	ids.sort()
	for id in ids:
		moved.add_instance(grid.instances[id].duplicate(), fixtures)
	var reach := PathService.distances(moved, moved.blocked_cells())
	for id in ids:
		var inst: Dictionary = moved.instances[id]
		var def := fixtures.get_type(inst["type_id"])
		if (def["access_edges"] as Array).is_empty():
			continue
		if AccessService.reachable_access(moved, def, inst["x"], inst["y"], inst["rotation"], reach).is_empty():
			return "entrance_cuts_off"
		if AccessService.is_register(def) and int(AccessService.register_plan(moved, def, inst["x"], inst["y"], inst["rotation"], moved.blocked_cells(), reach)["slots"]) == 0:
			return "entrance_cuts_off"
	return ""
