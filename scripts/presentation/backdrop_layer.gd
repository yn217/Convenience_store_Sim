class_name BackdropLayer
extends Node2D
## Street scene around the store: a dark-teal ground that fades to a vignette, a paving ring with joints,
## an apron with a door mat and an OPEN A-board on the entrance side, a kerb and road strip further out on that
## side, planters and trees at the outer corners. All procedural shapes, no external art.
## The layer is drawn behind the store floor (show_behind_parent), uses the same IsoProjection as the floor, and
## never takes input. The geometry is pure (layout_items); sync() redraws only when the layout, camera or viewport
## changes, so nothing is recomputed per frame.

const SIDE_WEST := 0
const SIDE_NORTH := 1
const SIDE_EAST := 2
const SIDE_SOUTH := 3

const GROUND := Color("62795b")
const POOL := Color(0.30, 0.50, 0.46, 0.10)
const PAVE := Color("d6d0c3")
const PAVE_ALT := Color("e1d9ca")
const PAVE_JOINT := Color("aca599")
const APRON := Color("d6cbb4")
const MAT := Color("3b3733")
const MAT_EDGE := Color("5b544d")
const KERB := Color("d8d5cc")
const ROAD := Color("50565b")
const ROAD_LINE := Color("e9e2c8")
const SIGN_FRAME := Color("2b2b2b")
const SIGN_FACE := Color("f4efe2")
const SIGN_OPEN := Color("c8432f")
const SIGN_TEXT := Color("ffffff")
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const TRUNK := Color("5a4636")
const BUSH_DARK := Color("2f5d3e")
const BUSH_MID := Color("4b7d4f")
const BUSH_HI := Color("6f9e62")
const PLANTER := Color("7a5a43")
const VIGNETTE_EDGE := Color(0.0, 0.0, 0.0, 0.16)
const VIGNETTE_CLEAR := Color(0.0, 0.0, 0.0, 0.0)

const PAVE_M := 2.0       ## paving ring width around the store footprint (tiles)
const KERB_M := 0.18
const PARK_DEPTH_M := 5.0  ## 3.8 m compact car plus wheel-stop and manoeuvring clearance
const ROAD_M := 3.0
const FAR_M := 14.0       ## how far the road and pool run along the edge, past the store
const SLAB_INSET := 0.04

var _key: Array = []
var _ops: Array = []
var _mesh: ArrayMesh          # every polygon and gradient batched into one mesh, so the layer costs one draw call
var _texts: Array = []        # text ops, drawn after the mesh


## Recomputes the backdrop when the layout, camera or viewport changed; otherwise does nothing.
## `dressed` (issue #110): the StoreDecor exterior layer draws the A-board, planters and trees, so the code-drawn
## ones are left out.
func sync(width: int, height: int, entrances: Array, proj: IsoProjection, viewport: Vector2, dressed: bool = false) -> void:
	var key := [width, height, entrances.duplicate(), proj.origin, proj.zoom, viewport, dressed]
	if key == _key:
		return
	_key = key
	_ops = layout_items(proj, width, height, entrances, viewport, dressed)
	_build_mesh()
	queue_redraw()


func _draw() -> void:
	if _mesh != null:
		draw_mesh(_mesh, null)
	for op in _texts:
		draw_string(ThemeDB.fallback_font, op["pos"], op["text"], HORIZONTAL_ALIGNMENT_CENTER, op["width"], op["size"], op["color"])


## Fan-triangulates the (convex) pieces in paint order into one vertex-coloured mesh.
func _build_mesh() -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	_texts = []
	for op in _ops:
		if op["kind"] == &"text":
			_texts.append(op)
			continue
		var pts: PackedVector2Array = op["points"]
		for k in range(1, pts.size() - 1):
			for idx in [0, k, k + 1]:
				verts.append(pts[idx])
				cols.append(op["colors"][idx] if op["kind"] == &"gradient" else op["color"])
	_mesh = null
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


## Every piece of the street, in paint order. Each entry is {"kind": &"poly"|&"gradient"|&"text", ...}:
## polys carry "points" and "color", gradients carry "points" and per-vertex "colors", text carries "pos",
## "text", "size", "width" and "color". Points are screen coordinates. Empty for a store without a floor.
static func layout_items(proj: IsoProjection, width: int, height: int, entrances: Array, viewport: Vector2, dressed: bool = false) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var side := entrance_side(width, height, entrances)
	var span := entrance_span(side, width, height, entrances)
	var far := maxf(float(width), float(height)) + FAR_M
	var along0 := -FAR_M
	var along1 := far

	# Ground: flat fill of the viewport, a soft lighter pool around the store, then the vignette on top.
	out.append(_poly(PackedVector2Array([Vector2.ZERO, Vector2(viewport.x, 0.0), viewport, Vector2(0.0, viewport.y)]), GROUND))
	for grow in [9.0, 6.0, 3.0]:
		out.append(_poly(_world_pts(proj, _rect_world(width, height, grow)), POOL))

	# Kerb and road on the entrance side, beyond the paving ring.
	var parking_end := PAVE_M + PARK_DEPTH_M
	var road_d0 := parking_end + KERB_M
	out.append(_poly(_side_quad(proj, side, width, height, parking_end, road_d0, along0, along1), KERB))
	out.append(_poly(_side_quad(proj, side, width, height, road_d0, road_d0 + ROAD_M, along0, along1), ROAD))
	# A continuous forecourt supports the existing bay sprites instead of placing them on a traffic lane.
	out.append(_poly(_side_quad(proj, side, width, height, PAVE_M, parking_end, -2.5, along1), Color("626367")))
	# Fine deterministic aggregate: quiet at the normal view, without per-frame noise or texture seams.
	for d in range(6):
		for k in range(int(along0), int(along1)):
			var jitter := FloorStyle.hash01(k, d, 19)
			var depth := road_d0 + 0.2 + float(d) * 0.45
			out.append(_poly(_side_quad(proj, side, width, height, depth, depth + 0.035, float(k) + jitter, float(k) + jitter + 0.16), Color(0.85, 0.86, 0.87, 0.07)))
	var dash_mid := road_d0 + ROAD_M * 0.5
	var a := along0
	while a < far:
		out.append(_poly(_side_quad(proj, side, width, height, dash_mid - 0.06, dash_mid + 0.06, a, a + 1.2), ROAD_LINE))
		a += 3.0

	# Crossing is aligned with the actual doorway, and spans only the public road.
	for stripe in range(6):
		var d := road_d0 + 0.2 + float(stripe) * 0.45
		out.append(_poly(_side_quad(proj, side, width, height, d, d + 0.24, span.x - 0.15, span.y + 0.15), ROAD_LINE))
	# Kerb joints and small drainage grates establish the pavement/forecourt boundary.
	for k in range(-2, int(along1), 2):
		out.append(_poly(_side_quad(proj, side, width, height, parking_end, road_d0, float(k), float(k) + 0.025), Color("a3a39c")))
		if k % 6 == 0:
			out.append(_poly(_side_quad(proj, side, width, height, parking_end - 0.24, parking_end - 0.06, float(k), float(k) + 0.48), Color("42494b")))
			for slit in range(5):
				var a0 := float(k) + 0.04 + float(slit) * 0.09
				out.append(_poly(_side_quad(proj, side, width, height, parking_end - 0.22, parking_end - 0.08, a0, a0 + 0.025), Color("8d9694")))

	# Paving ring: joint colour underneath, then one inset slab per tile outside the store footprint.
	out.append(_poly(_world_pts(proj, _rect_world(width, height, PAVE_M)), PAVE_JOINT))
	for j in range(-int(PAVE_M), height + int(PAVE_M)):
		for i in range(-int(PAVE_M), width + int(PAVE_M)):
			if i >= 0 and i < width and j >= 0 and j < height:
				continue
			var slab := Rect2(i - 0.5 + SLAB_INSET, j - 0.5 + SLAB_INSET, 1.0 - SLAB_INSET * 2.0, 1.0 - SLAB_INSET * 2.0)
			var col := PAVE if FloorStyle.hash01(i, j, 7) < 0.5 else PAVE_ALT
			out.append(_poly(_world_pts(proj, slab), col))
			# Subdivide each metre slab into smaller, readable pavers while retaining the original ring geometry.
			var joint := Rect2(float(i) - 0.48, float(j) - 0.015, 0.96, 0.03)
			out.append(_poly(_world_pts(proj, joint), Color("c1b9ab")))
			joint = Rect2(float(i) - 0.015, float(j) - 0.48, 0.03, 0.96)
			out.append(_poly(_world_pts(proj, joint), Color("c1b9ab")))

	# Apron along the entrance, door mats in front of each entrance tile, and the A-board sign.
	out.append(_poly(_side_quad(proj, side, width, height, 0.0, PAVE_M, span.x - 1.0, span.y + 1.0), APRON))
	for e in entrances:
		var t: Vector2i = e
		var along := float(_along_coord(side, t))
		if not _on_side(side, t, width, height):
			continue
		out.append(_poly(_side_quad(proj, side, width, height, 0.15, 0.95, along - 0.38, along + 0.38), MAT_EDGE))
		out.append(_poly(_side_quad(proj, side, width, height, 0.22, 0.88, along - 0.30, along + 0.30), MAT))
	# The apron itself sits behind the entrance-side wall, so the A-board stands on the visible pavement at the
	# front corner of that side (the end of the edge that is closest to the viewer).
	var front := float(height - 1) + 0.7 if side == SIDE_WEST or side == SIDE_EAST else float(width - 1) + 0.7
	if not dressed:
		out.append_array(_a_board(proj, side_point(side, 1.2, front, width, height)))

		# Planters at the outer corners and trees beyond the paving.
		var s := proj.zoom
		var x0 := -0.5
		var y0 := -0.5
		var x1 := width - 0.5
		var y1 := height - 0.5
		for corner in [Vector2(x1 + 1.0, y1 + 1.0), Vector2(x1 + 1.0, y0 - 1.0)]:
			out.append_array(_planter(proj.world_to_screen(corner.x, corner.y), s))
		for tree in [Vector2(x1 + 3.6, y1 + 3.4), Vector2(x1 + 3.4, y0 - 3.2), Vector2(x0 - 7.0, y0 + 1.5)]:
			out.append_array(_tree(proj.world_to_screen(tree.x, tree.y), s))

	out.append_array(_vignette(viewport))
	return out


## Side of the store the entrance is on: west (x = 0) by default, else north, east or south.
static func entrance_side(width: int, height: int, entrances: Array) -> int:
	var sides := [SIDE_WEST, SIDE_NORTH, SIDE_EAST, SIDE_SOUTH]
	for side in sides:
		for e in entrances:
			if _on_side(side, e, width, height):
				return side
	return SIDE_WEST


## Along-edge range (tile coordinates) covered by the entrance tiles on that side, padded by half a tile.
static func entrance_span(side: int, width: int, height: int, entrances: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for e in entrances:
		var t: Vector2i = e
		if _on_side(side, t, width, height):
			var c := float(_along_coord(side, t))
			lo = minf(lo, c)
			hi = maxf(hi, c)
	if lo == INF:
		var mid := float(height) * 0.5 if side == SIDE_WEST or side == SIDE_EAST else float(width) * 0.5
		return Vector2(mid - 0.5, mid + 0.5)
	return Vector2(lo - 0.5, hi + 0.5)


## World point at `depth` metres out from the store edge on `side`, at tile coordinate `along` on that edge.
static func side_point(side: int, depth: float, along: float, width: int, height: int) -> Vector2:
	var x0 := -0.5
	var y0 := -0.5
	var x1 := width - 0.5
	var y1 := height - 0.5
	match side:
		SIDE_WEST:
			return Vector2(x0 - depth, along)
		SIDE_NORTH:
			return Vector2(along, y0 - depth)
		SIDE_EAST:
			return Vector2(x1 + depth, along)
	return Vector2(along, y1 + depth)


static func _on_side(side: int, t: Vector2i, width: int, height: int) -> bool:
	match side:
		SIDE_WEST:
			return t.x == 0
		SIDE_NORTH:
			return t.y == 0
		SIDE_EAST:
			return t.x == width - 1
	return t.y == height - 1


static func _along_coord(side: int, t: Vector2i) -> int:
	return t.y if side == SIDE_WEST or side == SIDE_EAST else t.x


## The outer edge of an entrance tile as two ground points (tile-unit world coordinates), on the wall it sits on.
## Used for the door line and anything that must sit at the threshold, whatever side the entrance is on.
static func door_segment(t: Vector2i, width: int, height: int) -> Array:
	var side := entrance_side(width, height, [t])
	var a := float(_along_coord(side, t))
	match side:
		SIDE_WEST:
			return [Vector2(-0.5, a - 0.5), Vector2(-0.5, a + 0.5)]
		SIDE_NORTH:
			return [Vector2(a - 0.5, -0.5), Vector2(a + 0.5, -0.5)]
		SIDE_EAST:
			return [Vector2(width - 0.5, a - 0.5), Vector2(width - 0.5, a + 0.5)]
	return [Vector2(a - 0.5, height - 0.5), Vector2(a + 0.5, height - 0.5)]


## Quad on the ground plane between two depths and two along-edge positions, projected to screen points.
static func _side_quad(proj: IsoProjection, side: int, width: int, height: int, d0: float, d1: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array([
		side_point(side, d0, a0, width, height), side_point(side, d1, a0, width, height),
		side_point(side, d1, a1, width, height), side_point(side, d0, a1, width, height),
	])
	return _world_pts(proj, pts)


## Floor-plane rectangle around the store footprint, grown by `grow` tiles on every side.
static func _rect_world(width: int, height: int, grow: float) -> Rect2:
	return Rect2(-0.5 - grow, -0.5 - grow, width + grow * 2.0, height + grow * 2.0)


static func _world_pts(proj: IsoProjection, r) -> PackedVector2Array:
	if r is Rect2:
		var rc: Rect2 = r
		r = PackedVector2Array([
			Vector2(rc.position.x, rc.position.y), Vector2(rc.end.x, rc.position.y),
			Vector2(rc.end.x, rc.end.y), Vector2(rc.position.x, rc.end.y),
		])
	var out := PackedVector2Array()
	for p in r:
		out.append(proj.world_to_screen(p.x, p.y))
	return out


static func _poly(points: PackedVector2Array, color: Color) -> Dictionary:
	return {"kind": &"poly", "points": points, "color": color}


static func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> Dictionary:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return _poly(pts, color)


## Screen-space vignette: transparent inside an inset rectangle, darkening towards the viewport edges.
static func _vignette(viewport: Vector2) -> Array:
	var vw := viewport.x
	var vh := viewport.y
	var ix0 := vw * 0.16
	var ix1 := vw * 0.84
	var iy0 := vh * 0.18
	var iy1 := vh * 0.82
	var e := VIGNETTE_EDGE
	var c := VIGNETTE_CLEAR
	return [
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(ix1, iy0), Vector2(ix0, iy0)]), "colors": PackedColorArray([e, e, c, c])},
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(vw, 0), Vector2(vw, vh), Vector2(ix1, iy1), Vector2(ix1, iy0)]), "colors": PackedColorArray([e, e, c, c])},
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(vw, vh), Vector2(0, vh), Vector2(ix0, iy1), Vector2(ix1, iy1)]), "colors": PackedColorArray([e, e, c, c])},
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(0, vh), Vector2(0, 0), Vector2(ix0, iy0), Vector2(ix0, iy1)]), "colors": PackedColorArray([e, e, c, c])},
	]


## Standing A-board: dark frame, cream face, red OPEN band with white lettering. `g` is its ground point.
static func _a_board(proj: IsoProjection, ground: Vector2) -> Array:
	var g := proj.world_to_screen(ground.x, ground.y)
	var s := proj.zoom
	var w := 14.0 * s
	var top := 34.0 * s
	var out: Array = []
	out.append(_ellipse(g + Vector2(3.0 * s, 1.0 * s), 18.0 * s, 5.0 * s, SHADOW))
	out.append(_poly(PackedVector2Array([g + Vector2(-w - 2.0 * s, 0), g + Vector2(w + 2.0 * s, 0), g + Vector2(w + 2.0 * s, -top), g + Vector2(-w - 2.0 * s, -top)]), SIGN_FRAME))
	out.append(_poly(PackedVector2Array([g + Vector2(-w, -2.0 * s), g + Vector2(w, -2.0 * s), g + Vector2(w, -top + 2.0 * s), g + Vector2(-w, -top + 2.0 * s)]), SIGN_FACE))
	out.append(_poly(PackedVector2Array([g + Vector2(-w, -top + 2.0 * s), g + Vector2(w, -top + 2.0 * s), g + Vector2(w, -top * 0.62), g + Vector2(-w, -top * 0.62)]), SIGN_OPEN))
	out.append({"kind": &"text", "pos": g + Vector2(0, -top * 0.62 - 2.0 * s), "text": "OPEN", "size": maxi(8, roundi(8.0 * s)), "width": w * 2.0, "color": SIGN_TEXT})
	return out


## Planter box with a rounded shrub on top. `g` is the ground point, `s` the zoom.
static func _planter(g: Vector2, s: float) -> Array:
	var out: Array = []
	out.append(_ellipse(g + Vector2(0, 2.0 * s), 26.0 * s, 7.0 * s, SHADOW))
	out.append(_poly(PackedVector2Array([g + Vector2(-18.0 * s, -12.0 * s), g + Vector2(18.0 * s, -12.0 * s), g + Vector2(18.0 * s, 0), g + Vector2(-18.0 * s, 0)]), PLANTER))
	out.append(_ellipse(g + Vector2(0, -22.0 * s), 26.0 * s, 18.0 * s, BUSH_DARK))
	out.append(_ellipse(g + Vector2(-5.0 * s, -28.0 * s), 17.0 * s, 12.0 * s, BUSH_MID))
	out.append(_ellipse(g + Vector2(-10.0 * s, -33.0 * s), 8.0 * s, 5.0 * s, BUSH_HI))
	return out


## Tree: trunk, a shadow on the ground and three stacked canopy blobs with a lit upper-left side.
static func _tree(g: Vector2, s: float) -> Array:
	var out: Array = []
	out.append(_ellipse(g + Vector2(6.0 * s, 2.0 * s), 34.0 * s, 13.0 * s, SHADOW))
	out.append(_poly(PackedVector2Array([g + Vector2(-3.0 * s, 0), g + Vector2(3.0 * s, 0), g + Vector2(3.0 * s, -26.0 * s), g + Vector2(-3.0 * s, -26.0 * s)]), TRUNK))
	out.append(_ellipse(g + Vector2(0, -64.0 * s), 40.0 * s, 34.0 * s, BUSH_DARK))
	out.append(_ellipse(g + Vector2(-8.0 * s, -74.0 * s), 30.0 * s, 26.0 * s, BUSH_MID))
	out.append(_ellipse(g + Vector2(-16.0 * s, -86.0 * s), 14.0 * s, 10.0 * s, BUSH_HI))
	return out
