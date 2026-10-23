class_name PathService
extends RefCounted
## 4-neighbour shortest paths on the store grid (09 §4). Uniform step cost, so a BFS with a
## fixed neighbour order N, E, S, W gives the same routes as the contract's A* tie-break.
## `blocked` is a Vector2i -> true set, which lets callers ask "what if this fixture were here".
## The cache is keyed by StoreGrid.revision: any structural change recomputes it.

const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var recompute_count: int = 0
var _grid_id: int = 0
var _revision: int = -1
var _distances: Dictionary = {}


## Distance (in steps) from the nearest free entrance tile to every reachable free cell.
static func distances(grid: StoreGrid, blocked: Dictionary) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for e in grid.entrance_tiles:
		if grid.in_bounds(e) and not blocked.has(e):
			dist[e] = 0
			queue.append(e)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in DIRS:
			var n := c + d
			if grid.in_bounds(n) and not blocked.has(n) and not dist.has(n):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist


## Shortest path from `start` to `goal` inclusive, or [] when none exists.
static func find_path(grid: StoreGrid, blocked: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not grid.in_bounds(start) or not grid.in_bounds(goal) or blocked.has(start) or blocked.has(goal):
		return out
	var parent := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size() and not parent.has(goal):
		var c := queue[head]
		head += 1
		for d in DIRS:
			var n := c + d
			if grid.in_bounds(n) and not blocked.has(n) and not parent.has(n):
				parent[n] = c
				queue.append(n)
	if not parent.has(goal):
		return out
	var cur := goal
	while cur != start:
		out.push_front(cur)
		cur = parent[cur]
	out.push_front(start)
	return out


## Cached reachability for the grid as it currently is.
func current_distances(grid: StoreGrid) -> Dictionary:
	if grid.get_instance_id() != _grid_id or grid.revision != _revision:
		_distances = distances(grid, grid.blocked_cells())
		_grid_id = grid.get_instance_id()
		_revision = grid.revision
		recompute_count += 1
	return _distances
