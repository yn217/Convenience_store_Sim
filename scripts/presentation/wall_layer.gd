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
const WAINSCOT := Color("cbc2b4")     ## lower wall: warm grey-beige
const TRIM := Color("e4ddd0")
const BASEBOARD := Color("7f776d")
const STRIPE_BLUE := Color("2f6db5")  ## chain stripe band (blue with thin white edges)
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
		else:
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, WAINSCOT_M, WALL_HEIGHT, WALL_TOP, &"wall"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, 0.0, WAINSCOT_M, WAINSCOT, &"wainscot"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, 0.0, BASE_M, BASEBOARD, &"baseboard"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, STRIPE_LO_M - STRIPE_EDGE_M, STRIPE_LO_M, STRIPE_WHITE, &"stripe_edge"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, STRIPE_LO_M, STRIPE_HI_M, STRIPE_BLUE, &"stripe"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, STRIPE_HI_M, STRIPE_HI_M + STRIPE_EDGE_M, STRIPE_WHITE, &"stripe_edge"))
			out.append(_quad(proj, wall, i - 0.5, j + 0.5, WALL_HEIGHT - TRIM_M, WALL_HEIGHT, TRIM, &"trim"))
		i = j + 1
	for k in range(1, length, LAMP_SPACING):
		if not gaps.has(k):
			out.append(_streak(proj, wall, k))
			out.append(_quad(proj, wall, k - LAMP_W * 0.5, k + LAMP_W * 0.5, LAMP_Z, LAMP_Z + LAMP_H, LAMP, &"lamp"))


## Soft light falling down the wall from a lamp: transparent at the wainscot top, brightest at the lamp.
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
