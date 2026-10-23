class_name AccessService
extends RefCounted
## Customer-facing access of fixtures (02 §D, 09 §4): which tiles in front of a fixture a
## customer can actually walk to from the entrance, and where a register's queue forms.
## `reach` is PathService.distances(): reachable free cell -> steps from the entrance.

const NORMAL := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const QUEUE_MAX := 3


## Access tiles a customer can reach, ordered by (distance, y, x) as the contract requires.
static func reachable_access(grid: StoreGrid, def: Dictionary, x: int, y: int, rotation: int, reach: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in PlacementRules.access_candidates(def, x, y, rotation):
		if reach.has(c) and not out.has(c):
			out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if reach[a] != reach[b]:
			return reach[a] < reach[b]
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	return out


static func is_register(def: Dictionary) -> bool:
	return int(def.get("register_queue_max_tiles", 0)) > 0


## Register service cell + queue line. Among the reachable access cells, pick the one with
## the longest straight run (up to 3 cells, including the service cell) along the front
## normal, then the shortest entrance distance, then the smallest (y, x).
## Returns {slots: 0} when no queue can form (the store cannot open).
static func register_plan(grid: StoreGrid, def: Dictionary, x: int, y: int, rotation: int, blocked: Dictionary, reach: Dictionary) -> Dictionary:
	var best := {"slots": 0, "service_cell": Vector2i(-1, -1), "queue_cells": [] as Array[Vector2i]}
	if def["access_edges"].is_empty():
		return best
	var normal: Vector2i = NORMAL[PlacementRules.rotate_edge(def["access_edges"][0], rotation)]
	var best_key := [0, 0, 0, 0]
	for c in reachable_access(grid, def, x, y, rotation, reach):
		var line: Array[Vector2i] = [c]
		for k in range(1, QUEUE_MAX):
			var n := c + normal * k
			if not grid.in_bounds(n) or blocked.has(n) or not reach.has(n):
				break
			line.append(n)
		# Larger is better for slots; smaller for distance, y, x -> negate those.
		var key := [line.size(), -reach[c], -c.y, -c.x]
		if _better(key, best_key):
			best_key = key
			best = {"slots": line.size(), "service_cell": c, "queue_cells": line}
	return best


static func _better(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false
