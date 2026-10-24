class_name RegisterDecor
extends RefCounted
## Issue #113: checkout-area dressing. For every enabled register (AccessService.is_register) the layout has three
## layers, drawn by StoreDecor (LAYER_REG_*):
##   floor (under the fixtures, over the floor): a square footprint on each queue cell of the register's line, and on the
##         first queue cell a small blue floor sticker with a raised label こちらにお並びください. Queue cells come from
##         AccessService.register_plan, the same helper the customers use.
##   back  (under the fixtures, over the walls): a back counter (code-drawn box: top face and two front faces) on the side
##         opposite the access edge. It stands inside the register's own footprint against its back edge, or on the wall
##         line when the tile behind the register is off the store, so the register body covers its lower part and its top
##         shows above the register. Nothing reaches a walkable cell, and the tile behind the register (where the clerk of
##         #104 stands) is never drawn on.
##   top   (over the fixtures): the back-counter appliances (coffee_machine, cigarette_shelf_generic, fryer_hot_snack_case)
##         standing on the counter top, then small code-drawn counter-top items (a tray with packs, a rack with coloured
##         packs, a donation box) on the register top.
## Pure functions of the layout and the catalog; StoreDecor caches the result. No input, no pathing impact.

const BACK_APPLIANCES: Array[String] = ["coffee_machine", "cigarette_shelf_generic", "fryer_hot_snack_case"]
const COUNTER_H := 1.6          ## back counter height (m), the back_counter_set manifest height
const COUNTER_DEPTH := 0.8      ## back counter depth (tile units): inside the footprint, or on the wall line
const COUNTER_GAP := 0.04       ## the counter stops this far short of each end of the back row
const COUNTER_SHADES: Array = [Color("dccaa6"), Color("b9986b"), Color("94764f")]   ## top, +x face, +y face
const MARK_Z := 0.01
const MARK_HALF := 0.42         ## a queue footprint is a square of this half-size (tile units), centred on the cell
const MARK_LINE := 0.07
const MARK_COLOR := Color("f2c94c")
const STICKER_HALF := 0.3       ## the floor sticker on the head of the line is 0.6 tile square
const SIGN_TEXT := "こちらにお並びください"
const SIGN_LABEL_Z := 0.5       ## the label floats above the sticker
const SIGN_FILL := Color("2f6db5")
const SIGN_TEXT_COLOR := Color("1f3a5c")

## Counter-top boxes: {u, v} centre across the register (u, along its long side) and toward the customers (v, along the
## access normal), half sizes su/sv, z0 above the register top, height h, and the base colour (top and faces are shaded).
const TOP_BOXES := [
	# tray with three packs
	[-0.45, 0.04, 0.20, 0.14, 0.00, 0.03, Color("e6e9ec")],
	[-0.52, 0.04, 0.035, 0.03, 0.03, 0.06, Color("d64545")],
	[-0.45, 0.04, 0.035, 0.03, 0.03, 0.06, Color("f2c94c")],
	[-0.38, 0.04, 0.035, 0.03, 0.03, 0.06, Color("5cb85c")],
	# small rack with four coloured packs on its shelf
	[0.12, -0.05, 0.11, 0.10, 0.00, 0.14, Color("5b6670")],
	[0.06, -0.10, 0.04, 0.035, 0.14, 0.05, Color("f2c94c")],
	[0.18, -0.10, 0.04, 0.035, 0.14, 0.05, Color("4a90d9")],
	[0.06, 0.00, 0.04, 0.035, 0.14, 0.05, Color("5cb85c")],
	[0.18, 0.00, 0.04, 0.035, 0.14, 0.05, Color("e04b4b")],
	# donation box
	[0.60, 0.02, 0.10, 0.10, 0.00, 0.16, Color("2f6db5")],
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
	if which == StoreDecor.LAYER_REG_BACK:
		return back_items(plans, width, height)
	if which == StoreDecor.LAYER_REG_FLOOR:
		return floor_items(plans)
	if which == StoreDecor.LAYER_REG_TOP:
		return appliance_items(plans, width, height) + top_items(plans)
	return []


## The back counter: one box per register, COUNTER_H tall, on the back row. Strip mode: inside the footprint against the
## back edge. Wall mode (the tile behind is off the store): on the wall line, one COUNTER_DEPTH out from the edge.
static func back_items(plans: Array, width: int, height: int) -> Array:
	var out: Array = []
	for p in plans:
		var back: Vector2i = p["back"]
		if back == Vector2i.ZERO:
			continue
		var geo := _back_geometry(p, width, height)
		if geo.is_empty():
			continue
		var b := Vector2(back)
		var along := Vector2(-b.y, b.x)
		out.append_array(_box(geo["centre"] + b * geo["s_mid"], along, b, geo["t_half"], geo["s_half"], 0.0, COUNTER_H, COUNTER_SHADES))
	return out


## The back-counter appliances standing on the counter top (sprites, rank 1 inside the layer).
static func appliance_items(plans: Array, width: int, height: int) -> Array:
	var out: Array = []
	for p in plans:
		var back: Vector2i = p["back"]
		if back == Vector2i.ZERO:
			continue
		var geo := _back_geometry(p, width, height)
		if geo.is_empty():
			continue
		var b := Vector2(back)
		var along := Vector2(-b.y, b.x)
		var lo: float = geo["lo"]
		var span: float = geo["span"]
		var mid: float = geo["along_mid"]
		var base: Vector2 = geo["centre"] + b * geo["s_mid"]
		for i in BACK_APPLIANCES.size():
			var pos := (lo - 0.5) + (i + 0.5) * span / BACK_APPLIANCES.size()
			out.append({"kind": &"sprite", "id": BACK_APPLIANCES[i], "x": (base + along * (pos - mid)).x,
				"y": (base + along * (pos - mid)).y, "z": COUNTER_H, "front": false, "rot": int(p["rotation"]), "rank": 1})
	return out


## Floor markings on every queue cell of the line, then the sticker and raised label on the first queue cell.
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
			var shades := [box[6].lightened(0.15), box[6], box[6].darkened(0.25)]
			out.append_array(_box(at, u, a, float(box[2]), float(box[3]), float(p["top"]) + float(box[4]), float(box[5]), shades))
	return out


## Geometry of a register's back counter, in tile units: the row centre, the back row span, and the counter box
## (s measured from the row centre toward the back, t along the row). Empty when there is no back row.
static func _back_geometry(p: Dictionary, width: int, height: int) -> Dictionary:
	var back: Vector2i = p["back"]
	var row := back_row(p["cells"], back)
	if row.is_empty():
		return {}
	var wall := false
	var centre := Vector2.ZERO
	var lo := INF
	var hi := -INF
	var across_y := back.x != 0
	for c in row:
		centre += Vector2(c)
		if not _in_store(c + back, width, height):
			wall = true
		var a := float(c.y if across_y else c.x)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	centre /= row.size()
	var s_mid := (0.5 + COUNTER_DEPTH * 0.5) if wall else (0.5 - COUNTER_DEPTH * 0.5)
	var span := hi - lo + 1.0
	return {
		"centre": centre, "lo": lo, "span": span, "along_mid": (lo + hi) * 0.5,
		"s_mid": s_mid, "s_half": COUNTER_DEPTH * 0.5, "t_half": span * 0.5 - COUNTER_GAP,
	}


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


## The sticker lies on the head cell of the line; the label is raised above it. Both are drawn under the fixtures.
static func _queue_sticker(c: Vector2i) -> Array:
	var h := STICKER_HALF
	return [
		{"kind": &"poly", "points": _rect(c.x - h, c.x + h, c.y - h, c.y + h, MARK_Z), "color": SIGN_FILL},
		{"kind": &"text", "at": Vector3(c.x, c.y, SIGN_LABEL_Z), "text": SIGN_TEXT, "color": SIGN_TEXT_COLOR},
	]


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
