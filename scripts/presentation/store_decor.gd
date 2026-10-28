class_name StoreDecor
extends Node2D
## Issue #110: static storefront and exterior dressing from the #111 / #107 prop sprites. Three instances in
## StoreWorld, each drawing one layer of the same pure layout:
##   LAYER_WALL     (WallDecor, over the WallLayer, under the fixtures): the storefront on the entrance-side wall,
##                  the reach-in cooler row and potted plants on the back walls.
##   LAYER_EXTERIOR (ExteriorDecor, behind the floor): parking and street furniture beyond the entrance side.
##   LAYER_FRONT    (FrontDecor, over the floor, under the fixtures): flower beds and planters on the near
##                  sides, which sit in front of the store.
##   LAYER_REG_FLOOR / LAYER_REG_TOP (#113, RegisterFloorDecor, RegisterTopDecor):
##                  the checkout area, built by RegisterDecor from the registers (back-counter props, queue markings,
##                  counter-top items). Their items are computed from the fixtures, not the wall or exterior layouts.
## Every item stands outside the walkable floor, or inside the register's own footprint (RegisterDecor). sync() rebuilds
## the draw list only when the layout, the fixtures' footprints, the camera or the viewport changes; _draw() replays it.
## Nothing here takes input, blocks pathing or moves with the panels. A prop whose asset is missing is skipped.

const LAYER_WALL := 0
const LAYER_EXTERIOR := 1
const LAYER_FRONT := 2
const LAYER_CANOPY := 3
const LAYER_REG_FLOOR := 4
const LAYER_REG_TOP := 5
const LAYER_EQUIPMENT := 6

const SIDE_WEST := 0
const SIDE_NORTH := 1
const SIDE_EAST := 2
const SIDE_SOUTH := 3

const NAME := "ミニマート青葉"   ## fictional store name (no real brand)
const FASCIA := Color("2f6db5")
const FASCIA_TEXT := Color("ffffff")
const SILL := Color("cfd9e2")
const FRAME := Color("7d8a96")
const WALL_OFFSET := -0.62     ## back-wall items stand just behind the wall plane (x or y = -0.5)
const STOREFRONT_OUT := -1.0   ## storefront boxes stand one tile outside the entrance-side wall
const FASCIA_Z0 := 2.4
const FASCIA_Z1 := 3.0         ## the sign band rises a little above the wall top (2.6 m)
const SILL_H := 0.45           ## near-side sill height (m)
const NEAR_FRAME_TOP := 2.25   ## transparent near-side glazing rises to the fascia (m)
const NEAR_CAP_Z0 := 2.25      ## thin fascia cap at the top of the front windows
const NEAR_CAP_Z1 := 2.4
const COOLER_COUNT := 6
const COOLER_START := 2
const FLOWER_STRIDE := 4
const LAMP_STRIDE := 6

## Draw op tags.
const OP_SPRITE := 0
const OP_POLY := 1
const OP_TEXT := 2
const OP_MESH := 3
const ExteriorMesh := preload("res://scripts/presentation/exterior_mesh.gd")
const ExteriorHvac := preload("res://assets/generated/props/exterior_hvac_v1/exterior_hvac_v1.png")

@export var layer := LAYER_EXTERIOR
var _sprites := PropSprites.new()
var _key: Array = []
var _ops: Array = []
var _items: Array = []


## Recomputes the draw list when the layout, the fixtures' footprints, the camera or the viewport changed.
func sync(width: int, height: int, entrances: Array, fixtures: Array, catalog: FixtureCatalog, proj: IsoProjection, viewport: Vector2) -> void:
	var key := [width, height, entrances.duplicate(), FloorStyle.layout_signature(fixtures), layer, proj.origin, proj.zoom, viewport]
	if key == _key:
		return
	_key = key
	if layer == LAYER_REG_FLOOR or layer == LAYER_REG_TOP:
		_items = RegisterDecor.layer_items(layer, width, height, entrances, fixtures, catalog)
	else:
		_items = _layer_items(width, height, entrances, occupied_cells(fixtures, catalog), layer)
	_build_ops(proj)
	queue_redraw()


func _draw() -> void:
	for op in _ops:
		match op[0]:
			OP_SPRITE:
				if op.size() > 3:
					draw_set_transform_matrix(op[3])
				draw_texture_rect(op[1], op[2], false)
				if op.size() > 3:
					draw_set_transform_matrix(Transform2D.IDENTITY)
			OP_POLY:
				draw_colored_polygon(op[1], op[2])
			OP_MESH:
				draw_mesh(op[1], null)
			_:
				if op.size() > 5:
					draw_set_transform_matrix(op[5])
				draw_string(_font(), op[1], op[2], HORIZONTAL_ALIGNMENT_LEFT, -1, op[3], op[4])
				if op.size() > 5:
					draw_set_transform_matrix(Transform2D.IDENTITY)


func _font() -> Font:
	var theme_font: Font = ThemeDB.get_default_theme().default_font
	return theme_font if theme_font != null else ThemeDB.fallback_font


## Projects the layout into cached draw ops. Sprites are sorted back to front (x + y), then the code-drawn
## fascia and text on top. Missing textures are skipped.
func _build_ops(proj: IsoProjection) -> void:
	_ops = []
	var font := _font()
	var sprites: Array = []
	var others: Array = []
	for it in _items:
		if it["kind"] == &"sprite":
			sprites.append(it)
		else:
			others.append(it)
	sprites.sort_custom(func(a, b): return _sprite_before(a, b))
	var s := proj.zoom / IsoProjection.SOURCE_SCALE
	# Road markings and contact faces belong below parked vehicles, never over their roofs.
	for it in others:
		if not it.get("ground", false):
			continue
		var points := PackedVector2Array()
		for p in it["points"]:
			points.append(proj.world_to_screen(p.x, p.y, p.z))
		_ops.append([OP_POLY, points, it["color"]])
	for it in sprites:
		if it["id"] == "exterior_hvac_v1":
			var ground := proj.world_to_screen(it["x"], it["y"])
			var hvac_scale := 0.17 * proj.zoom
			var anchor := Vector2(800, 900) * hvac_scale
			var hvac_size := Vector2(ExteriorHvac.get_size()) * hvac_scale
			if it.get("mirror", false):
				var left := ground.x + anchor.x - hvac_size.x
				var target := Rect2(Vector2(left, ground.y - anchor.y), hvac_size)
				_ops.append([OP_SPRITE, ExteriorHvac, target, Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(2.0 * left + hvac_size.x, 0))])
			else:
				_ops.append([OP_SPRITE, ExteriorHvac, Rect2(ground - anchor, hvac_size)])
			continue
		var info := _sprites.texture(it["id"], int(it.get("rot", 0)))
		if info.is_empty():
			continue
		var ground := proj.world_to_screen(it["x"], it["y"], float(it.get("z", 0.0)))   ## z: an item standing on a counter top
		var top_left := proj.sprite_top_left(ground, info["anchor"])
		var size: Vector2 = info["size"]
		for tex in info["layers"]:
			_ops.append([OP_SPRITE, tex, Rect2(top_left, size * s)])
	for it in others:
		if it.get("ground", false):
			continue
		if it["kind"] == &"poly":
			var pts := PackedVector2Array()
			for p in it["points"]:
				pts.append(proj.world_to_screen(p.x, p.y, p.z))
			_ops.append([OP_POLY, pts, it["color"]])
		elif it["kind"] == &"text":
			var at: Vector3 = it["at"]
			var size_px := maxi(8, roundi(float(it.get("font_px", 14.0)) * proj.zoom))
			var width := font.get_string_size(it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			var pos := proj.world_to_screen(at.x, at.y, at.z) + Vector2(-width * 0.5, size_px * 0.35 + float(it.get("dy", 0.0)) * proj.zoom)
			if it.has("wall_side"):
				# A vertical sign plane has a sloping baseline, while glyph stems stay vertical.
				var side: int = it["wall_side"]
				var slope := -0.5 if side == SIDE_WEST or side == SIDE_EAST else 0.5
				var basis := Transform2D(Vector2(1.0, slope), Vector2(0.0, 1.0), proj.world_to_screen(at.x, at.y, at.z))
				_ops.append([OP_TEXT, Vector2(-width * 0.5, size_px * 0.35), it["text"], size_px, it["color"], basis])
			else:
				_ops.append([OP_TEXT, pos, it["text"], size_px, it["color"]])
	_batch_polygons()


## Batch only adjacent geometry so sprite/text/alpha paint order remains unchanged.
func _batch_polygons() -> void:
	var compact: Array = []
	var faces: Array = []
	for op in _ops:
		if op[0] == OP_POLY:
			faces.append({"points": op[1], "color": op[2]})
		else:
			if not faces.is_empty():
				compact.append([OP_MESH, ExteriorMesh.from_faces(faces)])
				faces = []
			compact.append(op)
	if not faces.is_empty():
		compact.append([OP_MESH, ExteriorMesh.from_faces(faces)])
	_ops = compact


## Sprite order: lower rank first (a counter's appliances have rank 1, so they draw over the counter), then back to front.
static func _sprite_before(a: Dictionary, b: Dictionary) -> bool:
	var ra: int = a.get("rank", 0)
	var rb: int = b.get("rank", 0)
	if ra != rb:
		return ra < rb
	return a["x"] + a["y"] < b["x"] + b["y"]


## Number of draw ops currently cached (tests and the perf notes).
func op_count() -> int:
	return _ops.size()


## ---------------------------------------------------------------------------------------------------------------
## Pure layout. Items: {"kind": &"sprite", "id", "x", "y", "front"} on the ground plane (tile-centre coordinates),
## {"kind": &"poly", "points": Array[Vector3], "color"} and {"kind": &"text", "at": Vector3, "text", "color"}.
## ---------------------------------------------------------------------------------------------------------------

## Tiles that a fixture footprint covers, as {Vector2i: true}. Empty when there is no catalog.
static func occupied_cells(fixtures: Array, catalog: FixtureCatalog) -> Dictionary:
	var out := {}
	if catalog == null:
		return out
	for inst in fixtures:
		var def: Dictionary = catalog.get_type(inst["type_id"])
		if def.is_empty():
			continue
		for c in StoreGrid.footprint_cells(def["footprint"], int(inst["x"]), int(inst["y"]), int(inst["rotation"])):
			out[c] = true
	return out


## The items of one layer (see the header). Polys and text only ever come from the wall layer.
static func _layer_items(width: int, height: int, entrances: Array, occupied: Dictionary, which: int) -> Array:
	if which == LAYER_WALL:
		return wall_items(width, height, entrances, occupied)
	if which == LAYER_CANOPY:
		return canopy_items(width, height, entrances)
	var out: Array = []
	for it in exterior_items(width, height, entrances):
		var is_equipment: bool = it.get("id", "") == "exterior_hvac_v1"
		if which == LAYER_EQUIPMENT:
			if is_equipment:
				out.append(it)
			continue
		if is_equipment:
			continue
		if (which == LAYER_FRONT) == bool(it.get("front", false)):
			out.append(it)
	return out


## Thin architectural front frame. StoreWorld cuts it away while interacting with the floor.
static func canopy_items(width: int, height: int, entrances: Array) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var side := BackdropLayer.entrance_side(width, height, entrances)
	if not _is_near(side):
		return out
	var n := _edge_len(side, width, height)
	var plane := float(width) - 0.5 if side == SIDE_EAST else float(height) - 0.5
	# A lightly tinted, full-height glazing pass restores the storefront silhouette in the observe view.
	# It is deliberately drawn in the canopy layer (above people and fixtures) with low alpha, so the
	# shop floor remains readable while reflections make the front read as glass rather than open air.
	for a in n:
		if _is_entrance_at(entrances, side, a, width, height):
			continue
		var pane_a := float(a) - 0.47
		var pane_b := float(a) + 0.47
		out.append({"kind": &"poly", "points": _band(side, plane, pane_a, pane_b, SILL_H + 0.01, 2.25), "color": Color(0.64, 0.83, 0.91, 0.075), "role": &"glazing_pane"})
		if a % 3 == 1:
			out.append({"kind": &"poly", "points": _band(side, plane - 0.004, pane_a + 0.11, pane_a + 0.19, 1.38, 2.18), "color": Color(1.0, 1.0, 1.0, 0.20), "role": &"glazing_reflection"})
	for strip in [[2.28, 2.78, Color("f5f6ee")], [2.38, 2.56, FASCIA], [2.26, 2.30, Color("9caaaf")], [2.72, 2.78, Color("d4dcdb")]]:
		out.append({"kind": &"poly", "points": _band(side, plane, -0.5, n - 0.5, strip[0], strip[1]), "color": strip[2]})
	# A narrow outward roof return provides real projected depth without covering the interior.
	var roof: Array = []
	for v in [Vector2(-0.5, 0.0), Vector2(n - 0.5, 0.0), Vector2(n - 0.5, 0.26), Vector2(-0.5, 0.26)]:
		var p := _plane_point(side, plane + v.y, 2.78)
		if side == SIDE_EAST:
			p.y = v.x
		else:
			p.x = v.x
		roof.append(p)
	out.append({"kind": &"poly", "points": roof, "color": Color("ffffff")})
	for b in range(0, n + 1, 2):
		var a := float(b) - 0.5
		out.append({"kind": &"poly", "points": _band(side, plane, a - 0.018, a + 0.018, NEAR_FRAME_TOP, 2.28), "color": Color(0.45, 0.55, 0.57, 0.6)})
	var label := fascia_label(side, width, height, plane)
	label["font_px"] = 32
	label["color"] = FASCIA
	var at: Vector3 = label["at"]
	at.z = 2.53
	label["at"] = at
	var mid := float(n - 1) * 0.5
	out.append({"kind": &"poly", "points": _band(side, plane, mid - 2.6, mid + 2.6, 2.32, 2.72), "color": Color("fbfcf8")})
	out.append(label)
	return out


## Storefront on the entrance side, the cooler row and corner plants on the back walls.
static func wall_items(width: int, height: int, entrances: Array, occupied: Dictionary) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var side := BackdropLayer.entrance_side(width, height, entrances)
	if side == SIDE_WEST or side == SIDE_NORTH:
		out.append_array(_far_storefront(width, height, entrances, side))
	else:
		out.append_array(_near_low_front(width, height, entrances, side))
	for wall in _back_walls(side):
		out.append_array(_back_wall(width, height, wall, entrances, occupied))
	return out


## Ground-plane items outside the store, flagged "front" when they stand on a near side. The entrance side is
## the side the default camera sees the least: the storefront hides the pavement right behind it, so the street
## furniture stands on the visible pavement past the front corner of that side. Coordinates come from
## BackdropLayer.side_point, so depth is measured from the store edge and nothing lands on the floor.
static func exterior_items(width: int, height: int, entrances: Array) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var side := BackdropLayer.entrance_side(width, height, entrances)
	var n := _edge_len(side, width, height)
	# Along the entrance side, the street items are placed from the door span, so they follow the entrance wherever it is.
	var span := BackdropLayer.entrance_span(side, width, height, entrances)
	# One additional car sits in the outer road lane beside the store, clear of the crosswalk and parking bay.
	# It uses a fixed ground anchor and the same axis rotation as the road, with no simulation or click target.
	var door_mid := (span.x + span.y) * 0.5
	var road_vehicle_a := float(n) * 0.25
	var road_vehicle_b := float(n) * 0.75
	var road_vehicle_along := road_vehicle_a if absf(road_vehicle_a - door_mid) > absf(road_vehicle_b - door_mid) else road_vehicle_b
	_add(out, "compact_car_painted_v2", side, width, height, BackdropLayer.PAVE_M + BackdropLayer.PARK_DEPTH_M + BackdropLayer.KERB_M + BackdropLayer.ROAD_M * 0.5, road_vehicle_along)
	out[-1]["rot"] = 0 if side == SIDE_SOUTH or side == SIDE_NORTH else 1
	out[-1]["role"] = "road_vehicle"
	_add(out, "nobori_banner_obento", side, width, height, 1.0, n - 1.0)
	_add(out, "open_a_board", side, width, height, 1.0, span.x - 0.8)
	_add(out, "vending_painted_v1", side, width, height, 1.0, span.y + 1.5)   # beside the door
	_add(out, "trash_recycle_bins", side, width, height, 1.0, span.y + 3.0)
	_add(out, "bicycle_rack_painted_v1", side, width, height, 1.1, 1.7)
	_add(out, "bench_painted_v1", side, width, height, 1.1, span.x - 2.0)
	if BackdropLayer.landscape_side(side) != side:
		_add(out, "flower_planter_painted_v1", side, width, height, 1.05, float(n) - 1.4)
	out.append_array(_pole_sign_items(side, width, height))
	var a := -1.0
	while a <= n + 6.0:
		_add(out, "street_lamp", side, width, height, 2.0, a)
		a += LAMP_STRIDE
	# One row, measured in metres. Keep the doorway approach clear across the forecourt.
	var bay := 0
	var along := 0.0
	while along + 2.5 <= span.x - 0.35:
		# The combined Area A artwork already carries the static parking paint and wheel stops.
		# Keep the vehicle as a separate world-anchored sprite so it can be changed independently.
		if bay == 0 and (side == SIDE_SOUTH or side == SIDE_NORTH) and PropSprites.is_available("compact_car_painted_v2"):
			_add(out, "compact_car_painted_v2", side, width, height, 4.6, along + 1.25)
			out[-1]["rot"] = 0 if side == SIDE_SOUTH or side == SIDE_NORTH else 1
			out[-1]["role"] = "parked_vehicle"
		along += 2.7
		bay += 1
	# Place the fixed equipment against the visible east side, away from the entrance.
	if width >= 8 and height >= 8:
		var equipment_side := SIDE_SOUTH if side == SIDE_EAST else SIDE_EAST
		var equipment_along := float(width if equipment_side == SIDE_SOUTH else height) * 0.41
		_add(out, "exterior_hvac_v1", equipment_side, width, height, 1.0, equipment_along)
		out[-1]["mirror"] = equipment_side == SIDE_SOUTH
	# The temporary individual tree placements are omitted. The combined BackdropLayer sidewalk panel replaces the
	# repeated planters along its edge; planters remain on other visible sides.
	var landscape_side := BackdropLayer.landscape_side(side)
	for near in _near_sides(side):
		if near == landscape_side:
			continue
		var nn := _edge_len(near, width, height)
		var f := 3.0
		while f < nn:
			# Leave a clear gap around the equipment on the east wall.
			var equipment_side := SIDE_SOUTH if side == SIDE_EAST else SIDE_EAST
			var near_equipment: bool = near == equipment_side and width >= 8 and height >= 8 and absf(f - float(nn) * 0.41) < 1.5
			if not near_equipment:
				_add(out, "flower_planter_painted_v1", near, width, height, 1.1, f)
			f += FLOWER_STRIDE
	return out


static func _pole_sign_items(side: int, width: int, height: int) -> Array:
	var centre := BackdropLayer.side_point(side, 1.45, -0.8, width, height)
	var plane := centre.x if side == SIDE_WEST or side == SIDE_EAST else centre.y
	var mid := centre.y if side == SIDE_WEST or side == SIDE_EAST else centre.x
	var out: Array = []
	for part in [
		[-0.06, 0.06, 0.0, 2.6, Color("899599")],
		[-0.88, 0.88, 2.0, 3.8, Color("77868c")],
		[-0.82, 0.82, 2.04, 3.76, Color("fffdf1")],
		[-0.76, 0.76, 3.08, 3.68, FASCIA],
		[-0.78, 0.78, 2.73, 3.03, Color("b73550")],
		[-0.78, 0.78, 2.39, 2.69, Color("326d9d")],
		[-0.78, 0.78, 2.05, 2.35, Color("7a4b91")],
	]:
		out.append({"kind": &"poly", "points": _band(side, plane, mid + part[0], mid + part[1], part[2], part[3]), "color": part[4], "front": _is_near(side)})
	for row in [["青葉24", 3.36, FASCIA_TEXT, 20], ["たばこ", 2.88, FASCIA_TEXT, 16], ["酒", 2.54, FASCIA_TEXT, 16], ["ATM", 2.20, FASCIA_TEXT, 16]]:
		var at := _plane_point(side, plane, row[1])
		if side == SIDE_WEST or side == SIDE_EAST:
			at.y = mid
		else:
			at.x = mid
		out.append({"kind": &"text", "at": at, "text": row[0], "color": row[2], "font_px": row[3], "wall_side": side, "front": _is_near(side)})
	return out


## Storefront on a far wall (west or north): a window per tile, storefront piers at both ends, the entrance tiles
## as doors, and a blue fascia band with the store name above the glass.
static func _far_storefront(width: int, height: int, entrances: Array, side: int) -> Array:
	var out: Array = []
	var n := _edge_len(side, width, height)
	for a in n:
		var door := _is_entrance_at(entrances, side, a, width, height)
		var id := "storefront_window"
		if door:
			id = "storefront_door"
		elif a == 0 or a == n - 1:
			id = "storefront_wall"
		var g := _wall_ground(side, float(a), STOREFRONT_OUT)
		out.append({"kind": &"sprite", "id": id, "x": g.x, "y": g.y, "front": false})
	out.append(_fascia(side, -0.5, n))
	out.append(fascia_label(side, width, height, -0.5))
	return out


## Near walls (east or south) get transparent, full-height shopfront glazing above a low sill, mullions every
## other tile, and a thin fascia cap at the top. The alpha keeps customers and fixtures readable behind the glass.
## The entrance is a clear opening with no sill, pane or frame in front of it.
## Sill and frames are merged into one polygon per run, which keeps the draw-op count low.
static func _near_low_front(width: int, height: int, entrances: Array, side: int) -> Array:
	var out: Array = []
	var n := _edge_len(side, width, height)
	var plane := float(width) - 0.5 if side == SIDE_EAST else float(height) - 0.5
	var run_start := -1
	for a in range(n + 1):
		var open := a < n and not _is_entrance_at(entrances, side, a, width, height)
		if open and run_start < 0:
			run_start = a
		elif not open and run_start >= 0:
			var a0 := float(run_start) - 0.5
			var a1 := float(a) - 0.5
			out.append({"kind": &"poly", "points": _band(side, plane, a0, a1, 0.0, SILL_H), "color": SILL})
			out.append({"kind": &"poly", "points": _band(side, plane, a0, a1, SILL_H, NEAR_FRAME_TOP), "color": Color(0.66, 0.86, 0.92, 0.16)})
			# Thin reflected sky streaks add depth to the cut-away glazing without hiding the shop interior.
			var reflection_at := a0 + 0.2
			while reflection_at + 0.5 < a1:
				out.append(_glass_reflection(side, plane, reflection_at, 0.5, SILL_H + 0.08, NEAR_FRAME_TOP - 0.06))
				reflection_at += 2.2
			# White metal housing above and below a slimmer blue ribbon; broken at the door opening.
			out.append({"kind": &"poly", "points": _band(side, plane, a0, a1, NEAR_CAP_Z0 - 0.025, NEAR_CAP_Z0 + 0.025), "color": Color("a0adb4")})
			out.append({"kind": &"poly", "points": _band(side, plane, a0, a1, NEAR_CAP_Z0 + 0.025, NEAR_CAP_Z1), "color": Color("f8faf8")})
			out.append({"kind": &"poly", "points": _band(side, plane, a0, a1, NEAR_CAP_Z0 + 0.065, NEAR_CAP_Z1 - 0.035), "color": FASCIA})
			out.append(_canopy_top(side, plane, a0, a1, 0.09))
			run_start = -1
	for b in range(0, n + 1, 2):
		if _is_entrance_at(entrances, side, b, width, height) or _is_entrance_at(entrances, side, b - 1, width, height):
			continue
		var fb := float(b) - 0.5
		out.append({"kind": &"poly", "points": _band(side, plane, fb - 0.018, fb + 0.018, 0.0, NEAR_FRAME_TOP), "color": FRAME})
	# Entrance jambs frame a clear opening. Only the thin white canopy bridges the top of the cutaway.
	var door_start := -1
	for a in range(n + 1):
		var door := a < n and _is_entrance_at(entrances, side, a, width, height)
		if door and door_start < 0:
			door_start = a
		elif not door and door_start >= 0:
			var d0 := float(door_start) - 0.5
			var d1 := float(a) - 0.5
			for edge in [d0, d1]:
				out.append({"kind": &"poly", "points": _band(side, plane, edge - 0.025, edge + 0.025, 0.0, NEAR_CAP_Z1 - 0.05), "color": FRAME})
			out.append({"kind": &"poly", "points": _band(side, plane, d0 - 0.08, d1 + 0.08, NEAR_CAP_Z1 - 0.05, NEAR_CAP_Z1), "color": Color("f9faf6")})
			out.append(_canopy_top(side, plane, d0 - 0.08, d1 + 0.08, 0.22))
			door_start = -1
	return out


## A narrow diagonal reflection painted on a pane in wall-plane coordinates; kept inside the glass opening.
static func _glass_reflection(side: int, plane: float, along: float, width: float, z0: float, z1: float) -> Dictionary:
	var points: Array[Vector3] = []
	for p in [Vector2(along, z0), Vector2(along + width * 0.42, z0), Vector2(along + width, z1), Vector2(along + width * 0.58, z1)]:
		if side == SIDE_EAST:
			points.append(Vector3(plane, p.x, p.y))
		else:
			points.append(Vector3(p.x, plane, p.y))
	return {"kind": &"poly", "points": points, "color": Color(0.92, 0.98, 1.0, 0.19), "role": "glass_reflection"}


static func _canopy_top(side: int, plane: float, a0: float, a1: float, depth: float) -> Dictionary:
	var p0 := _plane_point(side, plane, NEAR_CAP_Z1)
	var p1 := _plane_point(side, plane + depth, NEAR_CAP_Z1)
	if side == SIDE_EAST:
		return {"kind": &"poly", "points": [Vector3(p0.x, a0, p0.z), Vector3(p0.x, a1, p0.z), Vector3(p1.x, a1, p1.z), Vector3(p1.x, a0, p1.z)], "color": Color("ffffff")}
	return {"kind": &"poly", "points": [Vector3(a0, p0.y, p0.z), Vector3(a1, p0.y, p0.z), Vector3(a1, p1.y, p1.z), Vector3(a0, p1.y, p1.z)], "color": Color("ffffff")}


## Fascia: a blue band between FASCIA_Z0 and FASCIA_Z1 over the whole wall.
static func _fascia(side: int, plane: float, n: int) -> Dictionary:
	return {"kind": &"poly", "points": _band(side, plane, -0.5, float(n) - 0.5, FASCIA_Z0, FASCIA_Z1), "color": FASCIA}


## The store name, centred on the fascia. Drawn after the fascia band.
static func fascia_label(side: int, width: int, height: int, plane: float) -> Dictionary:
	var n := _edge_len(side, width, height)
	var mid := (float(n) - 1.0) * 0.5
	var at := _plane_point(side, plane, (FASCIA_Z0 + FASCIA_Z1) * 0.5)
	if side == SIDE_WEST or side == SIDE_EAST:
		at.y = mid
	else:
		at.x = mid
	return {"kind": &"text", "at": at, "text": NAME, "color": FASCIA_TEXT, "wall_side": side}


## Back walls are the far walls that are not the entrance side: a reach-in cooler row along the middle of each,
## and potted plants at the two ends when the floor corner next to them is empty.
static func _back_wall(width: int, height: int, wall: int, entrances: Array, occupied: Dictionary) -> Array:
	var out: Array = []
	var n := _edge_len(wall, width, height)
	var count := clampi(n - COOLER_START - 2, 0, COOLER_COUNT)
	for k in count:
		var g := _wall_ground(wall, float(COOLER_START + k), WALL_OFFSET)
		out.append({"kind": &"sprite", "id": "reachin_cooler_row", "x": g.x, "y": g.y, "front": false})
	for end in [0, n - 1]:
		var floor_cell := _floor_cell(wall, end)
		if occupied.has(floor_cell) or _is_entrance(entrances, floor_cell):
			continue
		var g := _wall_ground(wall, float(end), WALL_OFFSET)
		out.append({"kind": &"sprite", "id": "potted_plant_small" if end == 0 else "potted_plant_large", "x": g.x, "y": g.y, "front": false})
	return out


## Adds a sprite at `depth` metres out from side `side` at tile coordinate `along`.
static func _add(out: Array, id: String, side: int, width: int, height: int, depth: float, along: float) -> void:
	var p := BackdropLayer.side_point(side, depth, along, width, height)
	if id == "green_street_tree_v1" or id == "cherry_tree_painted_v1":
		var contact: Array = []
		for i in 20:
			var angle := TAU * float(i) / 20.0
			contact.append(Vector3(p.x + cos(angle) * 0.65, p.y + sin(angle) * 0.65, 0.0))
		out.append({"kind": &"poly", "points": contact, "color": Color(0.13, 0.20, 0.09, 0.16), "ground": true, "role": "tree_contact", "front": _is_near(side)})
	out.append({"kind": &"sprite", "id": id, "x": p.x, "y": p.y, "front": _is_near(side)})


static func _is_near(side: int) -> bool:
	return side == SIDE_EAST or side == SIDE_SOUTH


static func _back_walls(side: int) -> Array:
	var out: Array = []
	if side != SIDE_WEST:
		out.append(SIDE_WEST)
	if side != SIDE_NORTH:
		out.append(SIDE_NORTH)
	return out


static func _near_sides(side: int) -> Array:
	var out: Array = []
	for s in [SIDE_EAST, SIDE_SOUTH]:
		if s != side:
			out.append(s)
	return out


static func _edge_len(side: int, width: int, height: int) -> int:
	return width if side == SIDE_NORTH or side == SIDE_SOUTH else height


## Whether an entrance tile opens the wall of `side` at along-wall index `a`.
static func _is_entrance_at(entrances: Array, side: int, a: int, width: int, height: int) -> bool:
	for e in entrances:
		var t: Vector2i = e
		var on := false
		match side:
			SIDE_WEST:
				on = t.x == 0
			SIDE_NORTH:
				on = t.y == 0
			SIDE_EAST:
				on = t.x == width - 1
			_:
				on = t.y == height - 1
		if on and _along(side, t) == a:
			return true
	return false


static func _along(side: int, t: Vector2i) -> int:
	return t.y if side == SIDE_WEST or side == SIDE_EAST else t.x


static func _is_entrance(entrances: Array, c: Vector2i) -> bool:
	for e in entrances:
		if e == c:
			return true
	return false


## The floor cell at the end `end` of a far wall (west: x = 0; north: y = 0).
static func _floor_cell(wall: int, end: int) -> Vector2i:
	return Vector2i(0, end) if wall == SIDE_WEST else Vector2i(end, 0)


## Ground point of a tile on a wall line: `offset` is the coordinate across the wall (-1 outside, -0.62 behind it).
static func _wall_ground(wall: int, along: float, offset: float) -> Vector2:
	return Vector2(offset, along) if wall == SIDE_WEST else Vector2(along, offset)


## A world point on a wall plane: `plane` is the across-wall coordinate (x for west and east walls, y for north and south).
static func _plane_point(side: int, plane: float, z: float) -> Vector3:
	if side == SIDE_WEST or side == SIDE_EAST:
		return Vector3(plane, 0.0, z)
	return Vector3(0.0, plane, z)


## A vertical band on a wall plane between two along-wall positions and two heights, as four world points.
static func _band(side: int, plane: float, a0: float, a1: float, z0: float, z1: float) -> Array:
	var pts: Array = []
	for pair in [[a0, z0], [a1, z0], [a1, z1], [a0, z1]]:
		var p := _plane_point(side, plane, pair[1])
		if side == SIDE_WEST or side == SIDE_EAST:
			p.y = pair[0]
		else:
			p.x = pair[0]
		pts.append(p)
	return pts
