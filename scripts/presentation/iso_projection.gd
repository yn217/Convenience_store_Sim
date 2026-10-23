class_name IsoProjection
extends RefCounted
## 2:1 diamond projection (02_GRID_AND_ASSET_CONTRACT §A). Pure math, no scene access.
##   screen_u = origin_u + zoom * 64 * (x - y)
##   screen_v = origin_v + zoom * (32 * (x + y) - 78.38367177 * z)
## (x, y) are tile-center world coordinates in tiles (1 tile = 1 m); z is height in metres.
## A tile (cx, cy) covers world x in [cx - 0.5, cx + 0.5] and y likewise, so its screen
## shape is the diamond whose inverse is a plain square: hit-test = floor(x + 0.5).

const HALF_TILE_W := 64.0
const HALF_TILE_H := 32.0
const Z_PX_PER_M := 78.38367177
const ZOOM_MIN := 0.5
const ZOOM_NORMAL := 1.0
const ZOOM_MAX := 2.0
## Sprites are authored at 2x (256x128 source px per tile diamond).
const SOURCE_SCALE := 2.0
## Back walls (WallLayer) rise this high above the far floor corner; fit and centring count them.
const WALL_HEIGHT_M := 2.6

var origin: Vector2 = Vector2.ZERO
var zoom: float = ZOOM_NORMAL


func set_zoom(value: float) -> void:
	zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)


func world_to_screen(x: float, y: float, z: float = 0.0) -> Vector2:
	return origin + zoom * Vector2(HALF_TILE_W * (x - y), HALF_TILE_H * (x + y) - Z_PX_PER_M * z)


## Inverse on the ground plane (z = 0). Returns tile-unit world coordinates.
func screen_to_world(p: Vector2) -> Vector2:
	var d := (p - origin) / zoom
	var a := d.x / HALF_TILE_W   # x - y
	var b := d.y / HALF_TILE_H   # x + y
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## Tile under a screen point. May lie outside the store; callers check bounds.
func screen_to_tile(p: Vector2) -> Vector2i:
	var w := screen_to_world(p)
	return Vector2i(floori(w.x + 0.5), floori(w.y + 0.5))


func tile_center(c: Vector2i) -> Vector2:
	return world_to_screen(c.x, c.y)


## Diamond corners, clockwise from the top: N(-.5,-.5), E(+.5,-.5), S(+.5,+.5), W(-.5,+.5).
func tile_diamond(c: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([
		world_to_screen(c.x - 0.5, c.y - 0.5),
		world_to_screen(c.x + 0.5, c.y - 0.5),
		world_to_screen(c.x + 0.5, c.y + 0.5),
		world_to_screen(c.x - 0.5, c.y + 0.5),
	])


## Bounding rect of the whole floor (width x height tiles) at the current origin/zoom.
func floor_bounds(width: int, height: int) -> Rect2:
	var top := world_to_screen(-0.5, -0.5)
	var right := world_to_screen(width - 0.5, -0.5)
	var bottom := world_to_screen(width - 0.5, height - 0.5)
	var left := world_to_screen(-0.5, height - 0.5)
	return Rect2(left.x, top.y, right.x - left.x, bottom.y - top.y)


## Zoom about a screen point: the world position under `pivot` stays under it.
func zoom_at(pivot: Vector2, new_zoom: float) -> void:
	var w := screen_to_world(pivot)
	set_zoom(new_zoom)
	origin += pivot - world_to_screen(w.x, w.y)


func pan(delta: Vector2) -> void:
	origin += delta


## Largest zoom (clamped to the allowed range) at which the whole floor fits, then centred.
func fit_floor(viewport_size: Vector2, width: int, height: int, margin: float = 32.0) -> void:
	zoom = ZOOM_NORMAL
	origin = Vector2.ZERO
	var b := floor_bounds(width, height)
	# The floor stays centred, so the walls' rise above the far corner is reserved on top and the same
	# amount is left free below: b.h + 2 * wall must fit. Walls scale with zoom like the floor (at zoom 1 here).
	var wall_px := Z_PX_PER_M * WALL_HEIGHT_M
	var avail := viewport_size - Vector2(margin, margin) * 2.0
	set_zoom(minf(avail.x / b.size.x, avail.y / (b.size.y + 2.0 * wall_px)))
	center_floor(viewport_size, width, height)


## Keeps at least `min_visible` px of the floor on screen along each axis so it cannot be panned away.
func clamp_to_viewport(viewport_size: Vector2, width: int, height: int, min_visible: float = 128.0) -> void:
	var b := floor_bounds(width, height)
	var d := Vector2.ZERO
	if b.end.x < min_visible:
		d.x = min_visible - b.end.x
	elif b.position.x > viewport_size.x - min_visible:
		d.x = (viewport_size.x - min_visible) - b.position.x
	if b.end.y < min_visible:
		d.y = min_visible - b.end.y
	elif b.position.y > viewport_size.y - min_visible:
		d.y = (viewport_size.y - min_visible) - b.position.y
	origin += d


## Moves the origin so the floor is centred in `viewport_size` (zoom unchanged).
func center_floor(viewport_size: Vector2, width: int, height: int) -> void:
	origin = Vector2.ZERO
	var b := floor_bounds(width, height)
	origin = viewport_size * 0.5 - (b.position + b.size * 0.5)


## Top-left of a sprite image whose ground anchor (source px) must sit on `ground`.
## Source images are 2x, shown at zoom/2 (02 §E), so anchors scale by zoom / SOURCE_SCALE.
func sprite_top_left(ground: Vector2, anchor_px: Vector2) -> Vector2:
	return ground - anchor_px * (zoom / SOURCE_SCALE)
