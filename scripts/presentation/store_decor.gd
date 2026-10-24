class_name StoreDecor
extends Node2D
## Issue #110: static storefront and exterior dressing from the #111 / #107 prop sprites. Three instances in
## StoreWorld, each drawing one layer of the same pure layout:
##   LAYER_WALL     (WallDecor, over the WallLayer, under the fixtures): the storefront on the entrance-side wall,
##                  the reach-in cooler row and potted plants on the back walls.
##   LAYER_EXTERIOR (ExteriorDecor, behind the floor): parking, street furniture and trees on the paving and road
##                  beyond the back and entrance sides.
##   LAYER_FRONT    (FrontDecor, over the floor, under the fixtures): trees, flower beds and planters on the near
##                  sides, which sit in front of the store.
##   LAYER_REG_BACK / LAYER_REG_FLOOR / LAYER_REG_TOP (#113, RegisterBackDecor, RegisterFloorDecor, RegisterTopDecor):
##                  the checkout area, built by RegisterDecor from the registers (back-counter props, queue markings,
##                  counter-top items). Their items are computed from the fixtures, not the wall or exterior layouts.
## Every item stands outside the walkable floor, or inside the register's own footprint (RegisterDecor). sync() rebuilds
## the draw list only when the layout, the fixtures' footprints, the camera or the viewport changes; _draw() replays it.
## Nothing here takes input, blocks pathing or moves with the panels. A prop whose asset is missing is skipped.

const LAYER_WALL := 0
const LAYER_EXTERIOR := 1
const LAYER_FRONT := 2
const LAYER_REG_BACK := 3
const LAYER_REG_FLOOR := 4
const LAYER_REG_TOP := 5

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
const NEAR_FRAME_TOP := 1.0    ## near-side window frames stop here (m)
const NEAR_CAP_Z0 := 1.0       ## thin fascia cap on the near front, on top of the frames
const NEAR_CAP_Z1 := 1.2
const COOLER_COUNT := 6
const COOLER_START := 2
const TREE_STRIDE := 6
const TREE_DEPTH_NEAR := 1.3
const TREE_DEPTH_BACK := 5.5
const FLOWER_STRIDE := 4
const LAMP_STRIDE := 6
const PARK_ROW_A := 2.5
const PARK_ROW_B := 3.5
const PARK_BOLLARD := 4.5
const PARK_MAX := 9

## Draw op tags.
const OP_SPRITE := 0
const OP_POLY := 1
const OP_TEXT := 2

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
	if layer >= LAYER_REG_BACK:
		_items = RegisterDecor.layer_items(layer, width, height, entrances, fixtures, catalog)
	else:
		_items = _layer_items(width, height, entrances, occupied_cells(fixtures, catalog), layer)
	_build_ops(proj)
	queue_redraw()


func _draw() -> void:
	for op in _ops:
		match op[0]:
			OP_SPRITE:
				draw_texture_rect(op[1], op[2], false)
			OP_POLY:
				draw_colored_polygon(op[1], op[2])
			_:
				draw_string(_font(), op[1], op[2], HORIZONTAL_ALIGNMENT_LEFT, -1, op[3], op[4])


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
	for it in sprites:
		var info := _sprites.texture(it["id"], int(it.get("rot", 0)))
		if info.is_empty():
			continue
		var ground := proj.world_to_screen(it["x"], it["y"], 0.0)
		var top_left := proj.sprite_top_left(ground, info["anchor"])
		var size: Vector2 = info["size"]
		for tex in info["layers"]:
			_ops.append([OP_SPRITE, tex, Rect2(top_left, size * s)])
	for it in others:
		if it["kind"] == &"poly":
			var pts := PackedVector2Array()
			for p in it["points"]:
				pts.append(proj.world_to_screen(p.x, p.y, p.z))
			_ops.append([OP_POLY, pts, it["color"]])
		elif it["kind"] == &"text":
			var at: Vector3 = it["at"]
			var size_px := maxi(10, roundi(14.0 * proj.zoom))
			var width := font.get_string_size(it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
			var pos := proj.world_to_screen(at.x, at.y, at.z) + Vector2(-width * 0.5, size_px * 0.35)
			_ops.append([OP_TEXT, pos, it["text"], size_px, it["color"]])


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
	var out: Array = []
	for it in exterior_items(width, height, entrances):
		if (which == LAYER_FRONT) == bool(it.get("front", false)):
			out.append(it)
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
	_add(out, "nobori_banner_obento", side, width, height, 1.0, n + 0.4)
	_add(out, "open_a_board", side, width, height, 1.0, n + 1.6)
	_add(out, "vending_machine", side, width, height, 1.0, span.y + 1.5)   # beside the door
	_add(out, "trash_recycle_bins", side, width, height, 1.0, span.y + 3.0)
	_add(out, "bicycle_stand", side, width, height, 1.1, n + 5.2)
	_add(out, "bench", side, width, height, 1.0, n + 6.3)
	_add(out, "pole_sign", side, width, height, 1.6, -1.0)
	var a := -1.0
	while a <= n + 6.0:
		_add(out, "street_lamp", side, width, height, 2.0, a)
		a += LAMP_STRIDE
	# Parking on the street side of the entrance wall, to the left of the door: two rows of bays, wheel stops, two cars.
	var last := mini(int(span.x) - 1, PARK_MAX)
	var a2 := 0.0
	while a2 < last:
		_add(out, "parking_lot_straight", side, width, height, PARK_ROW_A, a2)
		_add(out, "parking_lot_straight", side, width, height, PARK_ROW_B, a2)
		if int(a2) % 2 == 0:
			_add(out, "car_stop_bollard", side, width, height, PARK_BOLLARD, a2)
		a2 += 1.0
	if last >= 2:
		_add(out, "parked_car_blue", side, width, height, PARK_ROW_A, 1.0)
	if last >= 4:
		_add(out, "parked_car_red", side, width, height, PARK_ROW_B, 3.0)
	# Back sides: cherry trees beyond the parking lot (behind the store, so they stay above the wall).
	for back in _back_walls(side):
		var nb := _edge_len(back, width, height)
		var t := 1.0
		var k := 0
		while t < nb:
			_add(out, "cherry_tree_a" if k % 2 == 0 else "cherry_tree_b", back, width, height, TREE_DEPTH_BACK, t)
			t += TREE_STRIDE
			k += 1
	# Near sides (in front of the store): cherry trees, flower beds and planters on the pavement.
	for near in _near_sides(side):
		var nn := _edge_len(near, width, height)
		var f := 1.0
		var j := 0
		while f < nn:
			_add(out, "cherry_tree_b" if j % 2 == 0 else "cherry_tree_a", near, width, height, TREE_DEPTH_NEAR, f)
			f += TREE_STRIDE
			j += 1
		f = 3.0
		while f < nn:
			_add(out, "flower_bed_planter", near, width, height, 1.1, f)
			f += FLOWER_STRIDE
		_add(out, "potted_plant_large", near, width, height, 1.2, 0.0)
		_add(out, "potted_plant_large", near, width, height, 1.2, float(nn) - 1.0)
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


## Near walls (east or south) get a LOW cut-away front: a sill (SILL_H), short window frames with a mullion every
## other tile up to NEAR_FRAME_TOP, and a thin fascia cap on top (NEAR_CAP_Z0..NEAR_CAP_Z1). Nothing rises above
## ~1.2 m, so the interior stays visible. The entrance is a clear opening with no sill or frame in front of it.
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
			out.append({"kind": &"poly", "points": _band(side, plane, float(run_start) - 0.5, float(a) - 0.5, 0.0, SILL_H), "color": SILL})
			run_start = -1
	for b in range(0, n + 1, 2):
		var fb := float(b) - 0.5
		out.append({"kind": &"poly", "points": _band(side, plane, fb - 0.04, fb + 0.04, 0.0, NEAR_FRAME_TOP), "color": FRAME})
	out.append({"kind": &"poly", "points": _band(side, plane, -0.5, float(n) - 0.5, NEAR_CAP_Z0, NEAR_CAP_Z1), "color": FASCIA})
	var label := fascia_label(side, width, height, plane)
	var at: Vector3 = label["at"]
	at.z = (NEAR_CAP_Z0 + NEAR_CAP_Z1) * 0.5
	label["at"] = at
	out.append(label)
	return out


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
	return {"kind": &"text", "at": at, "text": NAME, "color": FASCIA_TEXT}


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
