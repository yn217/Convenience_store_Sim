class_name ClerkPlacement
extends RefCounted
## Where the clerk stands behind a register (#104). Presentation only: the clerk is drawn from the snapshot's
## fixtures and customers and never read by the simulation, and it is not a picking target.
## The clerk stands on the register's back side (opposite its access edge), one tile behind the counter's
## centre, and faces the customer side (the access edge). Its cell (the tile behind the counter) gives its depth.

const BEHIND_TILES := 1.0
const EDGE_DIR := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}


## The clerk's pose: the checkout pose while a customer of its register is in CHECKOUT, idle otherwise.
static func anim_for(busy: bool) -> String:
	return "checkout" if busy else "idle"


## A register: a fixture that sells (no shelf categories) and has a checkout queue.
static func is_register(def: Dictionary) -> bool:
	return def.get("allowed_categories", []).is_empty() and int(def.get("register_queue_max_tiles", 0)) > 0 \
		and not def.get("access_edges", []).is_empty()


## Clerk placement for a register at (x, y) with `rotation`: {"cell": Vector2i tile behind the counter,
## "pos": Vector2 feet point in tile units, "facing": CustomerSprites facing toward the access edge}.
## Empty when the register has no footprint or no access edge.
static func placement(def: Dictionary, x: int, y: int, rotation: int) -> Dictionary:
	var cells := StoreGrid.footprint_cells(def["footprint"], x, y, rotation)
	var edges: Array = def.get("access_edges", [])
	if cells.is_empty() or edges.is_empty():
		return {}
	var access := PlacementRules.rotate_edge(String(edges[0]), rotation)
	var dir: Vector2i = EDGE_DIR[access]
	var back := -dir
	var behind: Array[Vector2i] = []
	var centre := Vector2.ZERO
	for c in cells:
		centre += Vector2(c)
		var b: Vector2i = c + back
		if not cells.has(b):
			behind.append(b)
	if behind.is_empty():
		return {}
	centre /= float(cells.size())
	behind.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return {
		"cell": behind[0],
		"pos": centre + Vector2(back) * BEHIND_TILES,
		"facing": CustomerSprites.facing_for(Vector2(dir), CustomerSprites.FACING_E),
	}
