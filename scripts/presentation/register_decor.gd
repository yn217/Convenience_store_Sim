class_name RegisterDecor
extends RefCounted
## Issue #113: checkout-area dressing. For every enabled register (AccessService.is_register) the layout has three
## layers, drawn by StoreDecor (LAYER_REG_*):
##   back  (under the fixtures, over the walls): the back-counter props (back_counter_set, coffee_machine,
##         cigarette_shelf_generic, fryer_hot_snack_case) on the side opposite the access edge. When the tile behind
##         the register is off the store (a wall), the props stand on that wall line; otherwise they stand inside the
##         register's own footprint against its back edge. No prop ever lands on a walkable cell, and the tile behind
##         the register (where the clerk of #104 stands) is never drawn on.
##   floor (over the floor, under the fixtures): a square footprint on each queue cell of the register's line and a
##         small floor sign ("こちらにお並びください") beside the head of the line. The queue cells come from
##         AccessService.register_plan, the same helper the customers use.
##   top   (over the fixtures): code-drawn counter-top items (tray, impulse-goods rack, donation box) on the register top.
## Pure functions of the layout and the catalog; StoreDecor caches the result. No input, no pathing impact.

const BACK_COUNTER := "back_counter_set"
const BACK_APPLIANCES: Array[String] = ["coffee_machine", "cigarette_shelf_generic", "fryer_hot_snack_case"]
const WALL_DEPTH := 0.62       ## props on a wall line stand just behind the wall plane (the StoreDecor WALL_OFFSET)
const STRIP_DEPTH := 0.25      ## props against the back edge stand inside the register's footprint
const MARK_Z := 0.01
const MARK_HALF := 0.42        ## a queue footprint is a square of this half-size (tile units), centred on the cell
const MARK_LINE := 0.07
const MARK_COLOR := Color("f2c94c")
const SIGN_TEXT := "こちらにお並びください"
const SIGN_Z := 0.02
const SIGN_LONG := 1.6         ## half length of the floor sign across the queue line (fits the guidance text on screen)
const SIGN_SHORT := 0.3        ## half depth of the floor sign along the queue line
const SIGN_OFFSET := 2.1       ## sign centre, measured from the head of the line across the queue (clear of the footprints)
const SIGN_FILL := Color("2f6db5")
const SIGN_TEXT_COLOR := Color("ffffff")

## Counter-top items: centre across the register (u, along its long side) and toward the customers (v, along the access
## normal), half sizes su/sv, height h above the register top, and the shades of top, customer-facing side, far side.
## Tile units: the register is one tile deep (0.92 m) and two tiles long.
const TOP_ITEMS := [
	{"u": -0.36, "v": 0.08, "su": 0.18, "sv": 0.13, "h": 0.04, "shades": [Color("e3e8ed"), Color("bcc5ce"), Color("9aa4ae")]},
	{"u": 0.12, "v": -0.06, "su": 0.10, "sv": 0.13, "h": 0.22, "shades": [Color("f0c96b"), Color("cf9f45"), Color("a8782e")]},
	{"u": 0.56, "v": 0.02, "su": 0.10, "sv": 0.10, "h": 0.16, "shades": [Color("ffffff"), Color("cfd6dd"), Color("9aa5ae")]},
]


## One entry per enabled register, in instance-id order:
## {"id", "rotation", "cells" (footprint, Array[Vector2i]), "access" (normal toward the customers), "back" (the opposite),
##  "top" (register height, m), "queue" (AccessService queue cells, empty when no line can form)}.
static func register_plans(width: int, height: int, entrances: Array, fixtures: Array, catalog: FixtureCatalog) -> Array:
	var plans: Array = []
	if catalog == null or width <= 0 or height <= 0:
		return plans
	var tiles: Array[Vector2i] = []
	for e in entrances:
		tiles.append(Vector2i(e))
	var grid := StoreGrid.create("view", width, height, tiles)
	for inst in fixtures:
		grid.add_instance({"instance_id": inst["instance_id"], "type_id": inst["type_id"], "x": int(inst["x"]), "y": int(inst["y"]),
			"rotation": int(inst["rotation"]), "enabled": bool(inst.get("enabled", true))}, catalog)
	var blocked := grid.blocked_cells()
	var reach := PathService.distances(grid, blocked)
	var ids: Array = grid.instances.keys()
	ids.sort()
	for id in ids:
		var inst: Dictionary = grid.instances[id]
		var def: Dictionary = catalog.get_type(inst["type_id"])
		if not AccessService.is_register(def) or not inst["enabled"]:
			continue
		var x: int = inst["x"]
		var y: int = inst["y"]
		var rot: int = inst["rotation"]
		var plan := AccessService.register_plan(grid, def, x, y, rot, blocked, reach)
		var access := _access_normal(def, rot)
		var dims: Dictionary = def.get("dimensions_m", {})
		plans.append({
			"id": id, "rotation": rot, "cells": StoreGrid.footprint_cells(def["footprint"], x, y, rot),
			"access": access, "back": -access, "top": float(dims.get("height", 1.2)), "queue": plan["queue_cells"],
			"blocked": blocked, "size": Vector2i(width, height),
		})
	return plans


## The draw items of one checkout layer (StoreDecor.LAYER_REG_*). Empty for any other layer.
static func layer_items(which: int, width: int, height: int, entrances: Array, fixtures: Array, catalog: FixtureCatalog) -> Array:
	var plans := register_plans(width, height, entrances, fixtures, catalog)
	if which == StoreDecor.LAYER_REG_BACK:
		return back_items(plans, width, height)
	if which == StoreDecor.LAYER_REG_FLOOR:
		return floor_items(plans)
	if which == StoreDecor.LAYER_REG_TOP:
		return top_items(plans) + sign_items(plans)
	return []


## Back-counter props. The back row is the footprint's cells on the back edge; the counter stands on that row's centre,
## and the three appliances stand along the row at the same depth (drawn after it, rank 1).
static func back_items(plans: Array, width: int, height: int) -> Array:
	var out: Array = []
	for p in plans:
		var back: Vector2i = p["back"]
		if back == Vector2i.ZERO:
			continue
		var row := back_row(p["cells"], back)
		if row.is_empty():
			continue
		var wall := false
		var centre := Vector2.ZERO
		for c in row:
			centre += Vector2(c)
			if not _in_store(c + back, width, height):
				wall = true
		centre /= row.size()
		var across_row: bool = back.x != 0   # the row runs along y when the back faces x
		var along := Vector2(0, 1) if across_row else Vector2(1, 0)
		var depth := WALL_DEPTH if wall else STRIP_DEPTH
		var base := centre + Vector2(back) * depth
		# The counter art turns to the row: rotation 1 is the long side along y, rotation 0 along x.
		out.append(_sprite(BACK_COUNTER, base, 1 if across_row else 0, 0))
		var lo := INF
		var hi := -INF
		for c in row:
			var a := float(c.y if across_row else c.x)
			lo = minf(lo, a)
			hi = maxf(hi, a)
		var span := hi - lo + 1.0
		var mid := (lo + hi) * 0.5
		for i in BACK_APPLIANCES.size():
			var pos := (lo - 0.5) + (i + 0.5) * span / BACK_APPLIANCES.size()
			out.append(_sprite(BACK_APPLIANCES[i], base + along * (pos - mid), int(p["rotation"]), 1))
	return out


## Floor markings on every queue cell of the line (drawn under the fixtures, over the floor).
static func floor_items(plans: Array) -> Array:
	var out: Array = []
	for p in plans:
		for c in p["queue"]:
			out.append_array(_queue_mark(c))
	return out


## The floor sign beside the head of each line. It is drawn over the fixtures (LAYER_REG_TOP) so a shelf never hides it.
static func sign_items(plans: Array) -> Array:
	var out: Array = []
	for p in plans:
		var access: Vector2i = p["access"]
		if access == Vector2i.ZERO or p["queue"].is_empty():
			continue
		out.append_array(_queue_sign(p["queue"][0], access, p["cells"], p["blocked"], p["size"]))
	return out


## Counter-top items on the register top, drawn as small boxes (top face and the two faces toward the viewer).
static func top_items(plans: Array) -> Array:
	var out: Array = []
	for p in plans:
		var access: Vector2i = p["access"]
		if access == Vector2i.ZERO:
			continue
		var centre := Vector2.ZERO
		for c in p["cells"]:
			centre += Vector2(c)
		centre /= p["cells"].size()
		var a := Vector2(access)
		var u := Vector2(-a.y, a.x)
		for item in TOP_ITEMS:
			var at := centre + u * float(item["u"]) + a * float(item["v"])
			out.append_array(_box(at, u, a, float(item["su"]), float(item["sv"]), float(p["top"]), float(item["h"]), item["shades"]))
	return out


## The cells of a footprint on its back edge (the side facing `back`), sorted along the edge.
static func back_row(cells: Array, back: Vector2i) -> Array:
	var row: Array = []
	for c in cells:
		if not cells.has(c + back):
			row.append(c)
	var along_y := back.x != 0
	row.sort_custom(func(a, b): return a.y < b.y if along_y else a.x < b.x)
	return row


## Unit normal of the register's access edge after rotation (toward the customers), or ZERO without an access edge.
static func _access_normal(def: Dictionary, rotation: int) -> Vector2i:
	var edges: Array = def.get("access_edges", [])
	if edges.is_empty():
		return Vector2i.ZERO
	return AccessService.NORMAL[PlacementRules.rotate_edge(edges[0], rotation)]


static func _in_store(c: Vector2i, width: int, height: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


static func _sprite(id: String, ground: Vector2, rot: int, rank: int) -> Dictionary:
	return {"kind": &"sprite", "id": id, "x": ground.x, "y": ground.y, "front": false, "rot": rot, "rank": rank}


static func _queue_mark(c: Vector2i) -> Array:
	var h := MARK_HALF
	var t := MARK_LINE
	var x0 := c.x - h
	var x1 := c.x + h
	var y0 := c.y - h
	var y1 := c.y + h
	var bars := [
		[x0, x1, y0, y0 + t], [x0, x1, y1 - t, y1], [x0, x0 + t, y0, y1], [x1 - t, x1, y0, y1],
	]
	var out: Array = []
	for b in bars:
		out.append({"kind": &"poly", "points": _rect(b[0], b[1], b[2], b[3], MARK_Z), "color": MARK_COLOR})
	return out


## The sign goes on the side of the queue line whose centre tile is free floor inside the store (not a fixture, not
## the register), so it is not hidden under a shelf; the first side is the fallback.
static func _queue_sign(head: Vector2i, access: Vector2i, cells: Array, blocked: Dictionary, size: Vector2i) -> Array:
	var side := Vector2(-access.y, access.x)
	var at := Vector2(head) + side * SIGN_OFFSET
	for s: Vector2 in [side, -side]:
		var c: Vector2 = Vector2(head) + s * SIGN_OFFSET
		var tile := Vector2i(roundi(c.x), roundi(c.y))
		if _in_store(tile, size.x, size.y) and not blocked.has(tile) and not cells.has(tile):
			at = c
			break
	var a := Vector2(access)
	var hx := absf(side.x) * SIGN_LONG + absf(a.x) * SIGN_SHORT
	var hy := absf(side.y) * SIGN_LONG + absf(a.y) * SIGN_SHORT
	return [
		{"kind": &"poly", "points": _rect(at.x - hx, at.x + hx, at.y - hy, at.y + hy, MARK_Z), "color": SIGN_FILL},
		{"kind": &"text", "at": Vector3(at.x, at.y, SIGN_Z), "text": SIGN_TEXT, "color": SIGN_TEXT_COLOR},
	]


## A box on the register top: its top face at z0 + h and the two faces that look toward the viewer (+x, +y).
static func _box(c: Vector2, u: Vector2, a: Vector2, su: float, sv: float, z0: float, h: float, shades: Array) -> Array:
	var hx := absf(u.x) * su + absf(a.x) * sv
	var hy := absf(u.y) * su + absf(a.y) * sv
	var x0 := c.x - hx
	var x1 := c.x + hx
	var y0 := c.y - hy
	var y1 := c.y + hy
	var z1 := z0 + h
	return [
		{"kind": &"poly", "points": _rect(x0, x1, y0, y1, z1), "color": shades[0]},
		{"kind": &"poly", "points": [Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1)], "color": shades[1]},
		{"kind": &"poly", "points": [Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], "color": shades[2]},
	]


## An axis-aligned rectangle at height z, as four world points.
static func _rect(x0: float, x1: float, y0: float, y1: float, z: float) -> Array:
	return [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)]
