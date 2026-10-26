class_name LightSpill
extends Node2D
## Issue #114 (outdoor light): at dusk and night the storefront throws warm light onto the pavement in front of it,
## street lamps (StoreDecor props) get a glow cone and pool, and the vending machine front glows. Presentation only.
## Drawn behind the exterior props (show_behind_parent), additive, so it reads as light on the ground.
## Strength is 0 in daylight, so nothing is drawn then. sync() rebuilds the cached ops only when the 10-minute clock
## bucket, the layout or the camera changes; _draw() replays them and never recomputes per frame.

const SPILL_COLOR := Color(1.0, 0.72, 0.42)
const SPILL_DEPTH := 2.6          ## how far the spill reaches onto the pavement, in tiles, from the storefront
const SPILL_STRENGTH := 0.45      ## alpha of the spill at the storefront at full night
const SPILL_DEPTHS := [0.0, 0.8, 1.7, SPILL_DEPTH]
const CONE_APEX_ALPHA := 0.28
const SPILL_DEPTH_ALPHA := [1.0, 0.55, 0.2, 0.0]
const SPILL_ALONG_ALPHA := [0.35, 1.0, 1.0, 0.35]   ## fades toward the ends of the storefront
const LAMP_HEIGHT := 4.0          ## lamp head height (m) where the cone starts
const LAMP_POOL_TILES := 1.6      ## radius of the lamp pool on the ground (tiles)
const LAMP_CONE_TILES := 0.7      ## radius of the cone's base on the ground (tiles)
const LAMP_STRENGTH := 0.5
const VENDING_POOL_TILES := 0.8
const VENDING_STRENGTH := 0.4
const CONE_SEGMENTS := 10
const TEXTURE_SIZE := 128

var _texture: GradientTexture2D
var _key: Array = []
var _polys: Array = []   ## {"points": PackedVector2Array, "colors": PackedColorArray}
var _pools: Array = []   ## {"centre": Vector2, "radius": float, "color": Color}


func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_texture = _make_texture()


## Rebuilds the cached spill, lamp and vending glows when anything they depend on changed (see the header).
func sync(time_sec: int, width: int, height: int, entrances: Array, proj: IsoProjection, viewport: Vector2) -> void:
	var key := [LightingModel.bucket(time_sec), width, height, entrances.duplicate(), proj.origin, proj.zoom, viewport]
	if key == _key:
		return
	_key = key
	_polys = []
	_pools = []
	var night := LightingModel.dusk_amount(time_sec)
	if width > 0 and height > 0 and night > 0.0:
		_build(night, width, height, entrances, proj)
	queue_redraw()


func _draw() -> void:
	var no_uv := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	for op in _polys:   # one triangle per call, so no polygon triangulation can fail on a degenerate quad
		var pts: PackedVector2Array = op["points"]
		var cols: PackedColorArray = op["colors"]
		for k in range(0, pts.size(), 3):
			draw_primitive(pts.slice(k, k + 3), cols.slice(k, k + 3), no_uv)
	for op in _pools:
		var r: float = op["radius"]
		var c: Vector2 = op["centre"]
		draw_texture_rect(_texture, Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0)), false, op["color"])


func _build(night: float, width: int, height: int, entrances: Array, proj: IsoProjection) -> void:
	var tile_px := proj.world_to_screen(1.0, 0.0).distance_to(proj.world_to_screen(0.0, 0.0))
	# Storefront spill: a grid of quads on the pavement, one row per depth step and one column per along step.
	for q in spill_quads(width, height, entrances):
		var s: Array = []
		var c: Array = []
		for i in 4:
			var w: Vector2 = q["points"][i]
			s.append(proj.world_to_screen(w.x, w.y))
			c.append(Color(SPILL_COLOR, SPILL_STRENGTH * night * float(q["alphas"][i])))
		_polys.append(_triangles([s[0], s[1], s[2], s[0], s[2], s[3]], [c[0], c[1], c[2], c[0], c[2], c[3]]))
	# Street lamps (StoreDecor props): a pool on the ground and a cone from the head down to it.
	var items := StoreDecor.exterior_items(width, height, entrances)
	for it in items:
		if it["kind"] != &"sprite":
			continue
		if it["id"] == "street_lamp":
			var g := proj.world_to_screen(it["x"], it["y"])
			_pools.append({"centre": g, "radius": LAMP_POOL_TILES * tile_px, "color": Color(SPILL_COLOR, LAMP_STRENGTH * night)})
			_polys.append(_cone(proj, it["x"], it["y"], night))
		elif it["id"] == "vending_machine" or it["id"] == "vending_painted_v1":
			var v := proj.world_to_screen(it["x"], it["y"], 0.6)
			_pools.append({"centre": v, "radius": VENDING_POOL_TILES * tile_px, "color": Color(0.85, 0.95, 1.0, VENDING_STRENGTH * night)})


## Cone of light from a lamp head to a ground ellipse: apex bright, base faded to nothing.
static func _cone_points(lx: float, ly: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in CONE_SEGMENTS:
		var a := TAU * float(i) / float(CONE_SEGMENTS)
		pts.append(Vector2(lx + cos(a) * LAMP_CONE_TILES, ly + sin(a) * LAMP_CONE_TILES * 0.5))
	return pts


func _cone(proj: IsoProjection, lx: float, ly: float, night: float) -> Dictionary:
	var apex := proj.world_to_screen(lx, ly, LAMP_HEIGHT)
	var ring := _cone_points(lx, ly)
	var s: Array = []
	var c: Array = []
	for i in ring.size():
		var a := proj.world_to_screen(ring[i].x, ring[i].y)
		var b := proj.world_to_screen(ring[(i + 1) % ring.size()].x, ring[(i + 1) % ring.size()].y)
		s.append_array([apex, a, b])
		c.append_array([Color(SPILL_COLOR, CONE_APEX_ALPHA * night), Color(SPILL_COLOR, 0.0), Color(SPILL_COLOR, 0.0)])
	return _triangles(s, c)


## A triangle list as one draw op: points and per-vertex colours, three of each per triangle.
static func _triangles(points: Array, colors: Array) -> Dictionary:
	return {"points": PackedVector2Array(points), "colors": PackedColorArray(colors)}


## The storefront spill on the pavement as world-space quads, for the entrance side that LightingModel and
## BackdropLayer use: {"points": 4 ground points (tile-unit world), "alphas": 4 per-vertex alphas (0..1)}. The spill
## starts on the wall line and fades out SPILL_DEPTH tiles away, and along the storefront it is strongest in the
## middle. Pure: no node, no camera.
static func spill_quads(width: int, height: int, entrances: Array) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var side := BackdropLayer.entrance_side(width, height, entrances)
	var n := width if side == BackdropLayer.SIDE_NORTH or side == BackdropLayer.SIDE_SOUTH else height
	var lo := -0.5
	var hi := float(n) - 0.5
	var step := (hi - lo) / float(SPILL_ALONG_ALPHA.size() - 1)
	for i in SPILL_DEPTHS.size() - 1:
		for j in SPILL_ALONG_ALPHA.size() - 1:
			var d0: float = SPILL_DEPTHS[i]
			var d1: float = SPILL_DEPTHS[i + 1]
			var a0 := lo + step * float(j)
			var a1 := a0 + step
			var pts: Array = [
				BackdropLayer.side_point(side, d0, a0, width, height),
				BackdropLayer.side_point(side, d0, a1, width, height),
				BackdropLayer.side_point(side, d1, a1, width, height),
				BackdropLayer.side_point(side, d1, a0, width, height),
			]
			var alphas: Array = [
				float(SPILL_DEPTH_ALPHA[i]) * float(SPILL_ALONG_ALPHA[j]),
				float(SPILL_DEPTH_ALPHA[i]) * float(SPILL_ALONG_ALPHA[j + 1]),
				float(SPILL_DEPTH_ALPHA[i + 1]) * float(SPILL_ALONG_ALPHA[j + 1]),
				float(SPILL_DEPTH_ALPHA[i + 1]) * float(SPILL_ALONG_ALPHA[j]),
			]
			out.append({"points": pts, "alphas": alphas})
	return out


func _make_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = TEXTURE_SIZE
	tex.height = TEXTURE_SIZE
	return tex
