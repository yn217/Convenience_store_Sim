class_name WallLayer
extends Node2D
## Issue #61 (walls): code-drawn back walls on the two far edges of the store (north: y = -0.5,
## west: x = -0.5), 2.6 m high. Lower wall is a warm grey band to 0.9 m with a dark baseboard at its foot;
## the upper wall is warm white with the chain's blue stripe (1.1-1.4 m, white edges), a thin top trim,
## and a small warm wall lamp about every three tiles with a soft light streak falling down the wall.
## Entrance tiles on a far edge become a glass door panel. Walls sit behind the object layer and never
## take input. The geometry is pure (wall_quads), and sync() redraws only when the layout, camera or
## viewport changes.

const WALL_TOP := Color("f2efe8")     ## upper wall: warm white
const WAINSCOT := Color("deded7")     ## lower wall: warm grey-beige
const TRIM := Color("f6f7f3")
const BASEBOARD := Color("7c898c")
const STRIPE_BLUE := Color("167ee0")  ## chain stripe band (blue with thin white edges)
const STRIPE_WHITE := Color("f7f8fa")
const GLASS := Color(0.624, 0.827, 0.941, 0.5)
const LAMP := UiTheme.WARM
const STREAK := Color(1.0, 0.93, 0.78)  ## light spill under each wall lamp

const WALL_HEIGHT := IsoProjection.WALL_HEIGHT_M
const WAINSCOT_M := 0.9
const BASE_M := 0.12
const STRIPE_LO_M := 1.1
const STRIPE_HI_M := 1.4
const STRIPE_EDGE_M := 0.04
const TRIM_M := 0.06
const LAMP_SPACING := 3
const LAMP_Z := 2.0
const LAMP_H := 0.16
const LAMP_W := 0.35
const STREAK_ALPHA := 0.32
const WALL_PLANE := -0.5

var _key: Array = []
var _quads: Array = []


## Recomputes the wall quads when any input changed; otherwise does nothing.
func sync(width: int, height: int, entrances: Array, proj: IsoProjection, viewport: Vector2) -> void:
	var key := [width, height, entrances.duplicate(), proj.origin, proj.zoom, viewport]
	if key == _key:
		return
	_key = key
	_quads = wall_quads(proj, width, height, entrances)
	queue_redraw()


func _draw() -> void:
	for q in _quads:
		if q.has("colors"):   # vertical gradients (lamp streaks)
			draw_polygon(q["points"], q["colors"])
		else:
			draw_colored_polygon(q["points"], q["color"])


## Every wall piece to draw, in paint order (north wall, then west wall). Each entry is
## {"kind": &"wall"|&"wainscot"|&"baseboard"|&"stripe"|&"stripe_edge"|&"trim"|&"glass"|&"streak"|&"lamp",
##  "wall": "north"|"west", "span": Vector2 (tile-index range along the wall), "points": PackedVector2Array,
##  "color": Color} (streaks carry "colors" per vertex instead of "color").
## Only the far edges are produced; an entrance on x = 0 opens the west wall, one on y = 0 the north wall.
static func wall_quads(proj: IsoProjection, width: int, height: int, entrances: Array) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var north_gap := {}
	var west_gap := {}
	for e in entrances:
		var t: Vector2i = e
		if t.x == 0 and t.y >= 0 and t.y < height:
			west_gap[t.y] = true
		if t.y == 0 and t.x >= 0 and t.x < width:
			north_gap[t.x] = true
	_wall_pieces(out, proj, "north", width, north_gap)
	_wall_pieces(out, proj, "west", height, west_gap)
	return out


static func _wall_pieces(out: Array, proj: IsoProjection, wall: String, length: int, gaps: Dictionary) -> void:
	var i := 0
	while i < length:
		var j := i
		var is_gap: bool = gaps.has(i)
		# A run is a stretch of tiles that are all openings, or all solid wall.
		while j + 1 < length and gaps.has(j + 1) == is_gap:
			j += 1
		if is_gap:
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, 0.0, WALL_HEIGHT, GLASS, &"glass"))
			_door_details(out, proj, wall, i - 0.5, j + 0.5)
		else:
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, WAINSCOT_M, WALL_HEIGHT, WALL_TOP, &"wall"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, 0.0, WAINSCOT_M, WAINSCOT, &"wainscot"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, 0.0, BASE_M, BASEBOARD, &"baseboard"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, STRIPE_LO_M - STRIPE_EDGE_M, STRIPE_LO_M, STRIPE_WHITE, &"stripe_edge"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, STRIPE_LO_M, STRIPE_HI_M, STRIPE_BLUE, &"stripe"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, STRIPE_HI_M, STRIPE_HI_M + STRIPE_EDGE_M, STRIPE_WHITE, &"stripe_edge"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, WALL_HEIGHT - TRIM_M, WALL_HEIGHT, TRIM, &"trim"))
		i = j + 1
	_panel_details(out, proj, wall, length, gaps)
	for k in range(1, length, LAMP_SPACING):
		if not gaps.has(k):
			out.append(_streak(proj, wall, k))
			out.append(_quad(proj, wall, k - LAMP_W * 0.5, k + LAMP_W * 0.5, LAMP_Z, LAMP_Z + LAMP_H, LAMP, &"lamp"))


## Soft light falling down the wall from a lamp: transparent at the wainscot top, brightest at the lamp.
static func _door_details(out: Array, proj: IsoProjection, wall: String, a: float, b: float) -> void:
	# Extruded metal jambs and narrow reflections keep the opening readable without an opaque door sprite.
	var metal := Color("9aaab3")
	for s in [a, (a + b) * 0.5, b]:
		out.append(_quad(proj, wall, s - 0.018, s + 0.018, 0.0, WALL_HEIGHT, metal, &"door_frame"))
	for z in [0.08, 2.32]:
		out.append(_quad(proj, wall, a, b, z, z + 0.045, metal, &"door_frame"))
	for s in [a + (b - a) * 0.26, a + (b - a) * 0.74]:
		out.append(_quad(proj, wall, s - 0.025, s + 0.025, 0.86, 1.2, Color("e9f0ee"), &"door_handle"))
		out.append(_quad(proj, wall, s + 0.06, s + 0.14, 1.35, 2.16, Color(0.94, 0.98, 1.0, 0.22), &"reflection"))
	# Safety decal at eye level, not an opaque patch over the entire window.
	out.append(_quad(proj, wall, a + 0.07, b - 0.07, 1.33, 1.38, Color(0.14, 0.49, 0.85, 0.55), &"door_decal"))


static func _panel_details(out: Array, proj: IsoProjection, wall: String, length: int, gaps: Dictionary) -> void:
	# Dimensions are metres; seams, cap and vents follow the existing wall plane at every zoom.
	var joint := Color(0.38, 0.44, 0.46, 0.22)
	for k in range(length):
		if gaps.has(k):
			continue
		var a := k - 0.5
		out.append(_quad(proj, wall, a, a + 0.018, 0.12, WALL_HEIGHT - 0.08, joint, &"panel_joint"))
		out.append(_quad(proj, wall, a + 0.018, a + 0.032, 0.12, WALL_HEIGHT - 0.08, Color(1.0, 1.0, 1.0, 0.32), &"panel_joint"))
		out.append(_quad(proj, wall, a, a + 1.0, 0.47, 0.482, joint, &"panel_joint"))
		out.append(_quad(proj, wall, a, a + 1.0, 2.43, 2.47, Color("c1cccd"), &"cap_shadow"))
		# A narrow folded-aluminium edge gives the roof cutaway a real section, below the existing height limit.
		out.append(_quad(proj, wall, a, a + 1.0, 2.48, 2.54, Color("b3c0c4"), &"cap_edge"))
		out.append(_quad(proj, wall, a, a + 1.0, 2.54, WALL_HEIGHT, Color("fcfcf8"), &"cap_edge"))
		if k % 6 == 3:
			out.append(_quad(proj, wall, k - 0.25, k + 0.25, 2.07, 2.36, Color("9eabad"), &"vent_frame"))
			out.append(_quad(proj, wall, k - 0.22, k + 0.22, 2.09, 2.34, Color("d8dfdc"), &"vent"))
			for z in [2.12, 2.17, 2.22, 2.27, 2.32]:
				out.append(_quad(proj, wall, k - 0.19, k + 0.19, z, z + 0.013, Color("78878a"), &"vent_louvre"))


static func _streak(proj: IsoProjection, wall: String, k: int) -> Dictionary:
	var q := _quad(proj, wall, k - LAMP_W * 0.9, k + LAMP_W * 0.9, WAINSCOT_M, LAMP_Z, STREAK, &"streak")
	var clear := Color(STREAK, 0.0)
	var lit := Color(STREAK, STREAK_ALPHA)
	q["colors"] = PackedColorArray([clear, clear, lit, lit])   # points: low a, low b, high b, high a
	return q


## A vertical quad on a far wall plane between tile-index positions a and b (heights z0..z1 in metres).
static func _quad(proj: IsoProjection, wall: String, a: float, b: float, z0: float, z1: float, color: Color, kind: StringName) -> Dictionary:
	var p0 := _along(wall, a)
	var p1 := _along(wall, b)
	var pts := PackedVector2Array([
		proj.world_to_screen(p0.x, p0.y, z0),
		proj.world_to_screen(p1.x, p1.y, z0),
		proj.world_to_screen(p1.x, p1.y, z1),
		proj.world_to_screen(p0.x, p0.y, z1),
	])
	return {"kind": kind, "wall": wall, "span": Vector2(a, b), "points": pts, "color": color}


static func _along(wall: String, s: float) -> Vector2:
	return Vector2(s, WALL_PLANE) if wall == "north" else Vector2(WALL_PLANE, s)
