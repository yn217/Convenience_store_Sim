class_name RegisterDecor
extends RefCounted
## Issue #113: checkout-area dressing, scoped down for review. For every enabled register (AccessService.is_register):
##   floor (StoreDecor.LAYER_REG_FLOOR, under the fixtures, over the floor): a square footprint on each queue cell of the
##         register's line (AccessService.register_plan, the same helper the customers use), and on the first queue cell a
##         small blue floor sticker with the guidance こちら / お並びください on two flat lines.
##   top   (StoreDecor.LAYER_REG_TOP, over the fixtures): small code-drawn counter-top items (a tray with packs, a
##         low rack with packs), drawn strictly inside the register's top face.
## The back counter and its appliances were removed for now (proper art comes from the asset lane); the tile behind the
## register, where the clerk of #104 stands, is left free. Pure functions of the layout and the catalog; no input, no
## pathing impact.

const MARK_Z := 0.01
const MARK_HALF := 0.42         ## a queue footprint is a square of this half-size (tile units), centred on the cell
const MARK_LINE := 0.07
const MARK_COLOR := Color("f2c94c")
const STICKER_HALF := 0.3       ## the floor sticker on the head of the line is 0.6 tile square
const SIGN_LINES: Array[String] = ["こちら", "お並びください"]
const SIGN_LINE_DY := [-6.0, 8.0]   ## screen px (at zoom 1) of each line, from the sticker centre
const SIGN_FILL := Color("2f6db5")
const SIGN_TEXT_COLOR := Color("ffffff")

## Counter-top boxes: {u, v} centre across the register (u, along its long side) and toward the customers (v, along the
## access normal), half sizes su/sv, z0 above the register top, height h, and the base colour (top and faces are shaded).
## Everything stays inside the register's top face (u within +-0.96, v within +-0.46 in tile units).
const TOP_BOXES := [
	# tray with three packs
	[-0.45, 0.04, 0.20, 0.13, 0.00, 0.025, Color("e6e9ec")],
	[-0.52, 0.04, 0.035, 0.03, 0.025, 0.05, Color("d64545")],
	[-0.45, 0.04, 0.035, 0.03, 0.025, 0.05, Color("f2c94c")],
	[-0.38, 0.04, 0.035, 0.03, 0.025, 0.05, Color("5cb85c")],
	# low display rack with four packs
	[0.14, -0.04, 0.16, 0.10, 0.00, 0.02, Color("8a949e")],
	[0.07, -0.08, 0.04, 0.035, 0.02, 0.05, Color("f2c94c")],
	[0.21, -0.08, 0.04, 0.035, 0.02, 0.05, Color("4a90d9")],
	[0.07, 0.00, 0.04, 0.035, 0.02, 0.05, Color("5cb85c")],
	[0.21, 0.00, 0.04, 0.035, 0.02, 0.05, Color("e04b4b")],
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
		})
	return plans


## The draw items of one checkout layer (StoreDecor.LAYER_REG_*). Empty for any other layer.
static func layer_items(which: int, width: int, height: int, entrances: Array, fixtures: Array, catalog: FixtureCatalog) -> Array:
	var plans := register_plans(width, height, entrances, fixtures, catalog)
	if which == StoreDecor.LAYER_REG_FLOOR:
		return floor_items(plans)
	if which == StoreDecor.LAYER_REG_TOP:
		return top_items(plans)
	return []


## Floor markings on every queue cell of the line, then the sticker and its two-line label on the first queue cell.
static func floor_items(plans: Array) -> Array:
	var out: Array = []
	for p in plans:
		for c in p["queue"]:
			out.append_array(_queue_mark(c))
		if not p["queue"].is_empty():
			out.append_array(_queue_sticker(p["queue"][0]))
	return out


## Counter-top items on the register top, drawn as small boxes (see TOP_BOXES).
static func top_items(plans: Array) -> Array:
	var out: Array = []
	for p in plans:
		var access: Vector2i = p["access"]
		if access == Vector2i.ZERO:
			continue
		var centre := _centre(p["cells"])
		var a := Vector2(access)
		var u := Vector2(-a.y, a.x)
		for box in TOP_BOXES:
			var at := centre + u * float(box[0]) + a * float(box[1])
			var base: Color = box[6]
			var shades := [base.lightened(0.15), base, base.darkened(0.25)]
			out.append_array(_box(at, u, a, float(box[2]), float(box[3]), float(p["top"]) + float(box[4]), float(box[5]), shades))
	return out


## Unit normal of the register's access edge after rotation (toward the customers), or ZERO without an access edge.
static func _access_normal(def: Dictionary, rotation: int) -> Vector2i:
	var edges: Array = def.get("access_edges", [])
	if edges.is_empty():
		return Vector2i.ZERO
	return AccessService.NORMAL[PlacementRules.rotate_edge(edges[0], rotation)]


static func _centre(cells: Array) -> Vector2:
	var centre := Vector2.ZERO
	for c in cells:
		centre += Vector2(c)
	return centre / cells.size()


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


## The sticker lies on the head cell of the line (0.6 tile square). The two label lines are drawn flat on it, centred,
## with a small vertical offset each, so the label stays on the floor in front of the register and never rises over it.
static func _queue_sticker(c: Vector2i) -> Array:
	var h := STICKER_HALF
	var out: Array = [{"kind": &"poly", "points": _rect(c.x - h, c.x + h, c.y - h, c.y + h, MARK_Z), "color": SIGN_FILL}]
	for i in SIGN_LINES.size():
		out.append({"kind": &"text", "at": Vector3(c.x, c.y, MARK_Z), "text": SIGN_LINES[i], "color": SIGN_TEXT_COLOR, "dy": SIGN_LINE_DY[i]})
	return out


## A box with its base at z0 (its top at z0 + h): the top face and the two faces that look toward the viewer (+x, +y).
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
