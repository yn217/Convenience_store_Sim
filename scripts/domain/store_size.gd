class_name StoreSize
extends RefCounted
## Store sizes (issue #145): small / medium / large from balance["store_sizes"] (width x height in tiles and the
## cost of extending to that size). The current size is read from the grid's dimensions, so nothing extra is
## saved. Resizing keeps the entrance wall where it is: the floor grows at the back (every row moves down by the
## added height) and to the right (x is kept), so the entrance and the fixtures keep their distance to it.

static func all(balance: Dictionary) -> Array:
	return balance.get("store_sizes", [])


static func find(balance: Dictionary, size_id: String) -> Dictionary:
	for s in all(balance):
		if s["size_id"] == size_id:
			return s
	return {}


## The size whose dimensions match the grid, or {} for a store of another size.
static func of_grid(balance: Dictionary, grid: StoreGrid) -> Dictionary:
	for s in all(balance):
		if int(s["width"]) == grid.width and int(s["height"]) == grid.height:
			return s
	return {}


## The next larger size (one tier up), or {} at the largest.
static func next(balance: Dictionary, grid: StoreGrid) -> Dictionary:
	var sizes := all(balance)
	var cur := of_grid(balance, grid)
	for i in sizes.size():
		if sizes[i] == cur and i + 1 < sizes.size():
			return sizes[i + 1]
	return {}


## A copy of `grid` at w x h: rows move down by (h - old height), columns stay, the entrance tiles move with the
## rows (x clamped into the new width). Returns {grid, dy} or {error} when a fixture would not fit.
static func resized(grid: StoreGrid, w: int, h: int, fixtures: FixtureCatalog) -> Dictionary:
	var dy := h - grid.height
	var entrances: Array[Vector2i] = []
	for e in grid.entrance_tiles:
		entrances.append(Vector2i(clampi(e.x, 0, w - 1), e.y + dy))
	var g := StoreGrid.create(grid.store_id, w, h, entrances)
	var ids := grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = grid.instances[id].duplicate()
		inst["y"] = int(inst["y"]) + dy
		if g.add_instance(inst, fixtures) != &"OK":
			return {"error": "fixtures_do_not_fit"}
	return {"grid": g, "dy": dy}
