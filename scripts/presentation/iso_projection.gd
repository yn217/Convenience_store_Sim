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
const ZOOM_MIN := 0.35
const ZOOM_NORMAL := 1.0
const ZOOM_MAX := 2.0
## Sprites are authored at 2x (256x128 source px per tile diamond).
const SOURCE_SCALE := 2.0
## Back walls (WallLayer) rise this high above the far floor corner; fit and centring count them.
const WALL_HEIGHT_M := 2.6
## Interior fit (the default view): the floor's bounding box fills this share of the safe area on its limiting axis,
## and the view centre sits this many tiles toward the entrances, so the storefront stays in view.
const INTERIOR_FILL := 0.9
const INTERIOR_SHIFT_TILES := 1.5
## Pan limit: the view centre may go this many tiles past the floor edges (the exterior ring).
const PAN_MARGIN_TILES := 4.0

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


## Pan limit: the point at the viewport centre (on the ground plane) may go at most `margin_tiles` past the floor's
## edges, so the player can look a few tiles outside the store (exterior) but never pan it away. Zoom is unchanged.
func clamp_to_store_area(viewport_size: Vector2, width: int, height: int, margin_tiles: float = PAN_MARGIN_TILES) -> void:
	var c := screen_to_world(viewport_size * 0.5)
	var clamped := Vector2(
		clampf(c.x, -0.5 - margin_tiles, width - 0.5 + margin_tiles),
		clampf(c.y, -0.5 - margin_tiles, height - 0.5 + margin_tiles))
	if clamped.is_equal_approx(c):
		return
	origin += world_to_screen(c.x, c.y) - world_to_screen(clamped.x, clamped.y)


## Interior fit (default view): the zoom at which the floor's bounding box fills `fill` of the safe `area` on its
## limiting axis. The walls and exterior may go off-screen; only the floor is sized. Clamped to the zoom range.
static func interior_zoom(area: Vector2, width: int, height: int, fill: float = INTERIOR_FILL) -> float:
	var n := float(width + height)
	if n <= 0.0 or area.x <= 0.0 or area.y <= 0.0:
		return ZOOM_NORMAL
	var by_width := fill * area.x / (n * HALF_TILE_W)    # floor bounds are (w+h)*64 wide and (w+h)*32 high at zoom 1
	var by_height := fill * area.y / (n * HALF_TILE_H)
	return clampf(minf(by_width, by_height), ZOOM_MIN, ZOOM_MAX)


## Tiles from the floor centre toward the entrances (their centroid), as a world offset of `tiles` length.
## Zero when there are no entrances or the entrances sit on the centre.
static func entrance_shift(entrances: Array, width: int, height: int, tiles: float = INTERIOR_SHIFT_TILES) -> Vector2:
	if entrances.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for e in entrances:
		sum += Vector2(e.x, e.y)
	var toward := sum / entrances.size() - Vector2((width - 1) * 0.5, (height - 1) * 0.5)
	if toward.length() < 0.01:
		return Vector2.ZERO
	return toward.normalized() * tiles


## Origin that puts the world point `floor centre + shift` at the centre of `area` (a screen rect) at `zoom`.
static func interior_origin(area: Rect2, zoom: float, width: int, height: int, shift: Vector2 = Vector2.ZERO) -> Vector2:
	var c := Vector2((width - 1) * 0.5, (height - 1) * 0.5) + shift
	var anchor := area.position + area.size * 0.5
	return anchor - zoom * Vector2(HALF_TILE_W * (c.x - c.y), HALF_TILE_H * (c.x + c.y))


## Applies the interior fit to this projection: zoom from the area, origin centred on the shifted floor centre.
## The shift toward the entrances may move the floor past the area's edge (the floor fills 90% of the limiting axis,
## so there is little slack on the other one); the origin is then pulled back so the whole floor stays inside `area`.
## The storefront stays in view because the floor's near edge is what remains at the bottom.
func fit_interior(area: Rect2, width: int, height: int, shift: Vector2 = Vector2.ZERO) -> void:
	set_zoom(interior_zoom(area.size, width, height))
	origin = interior_origin(area, zoom, width, height, shift)
	var b := floor_bounds(width, height)
	if b.size.x <= area.size.x and b.size.y <= area.size.y:
		origin += Vector2(_pull_into(b.position.x, b.end.x, area.position.x, area.end.x), _pull_into(b.position.y, b.end.y, area.position.y, area.end.y))


## Offset that moves a span [lo, hi] back inside [a0, a1] (0 when it already fits).
static func _pull_into(lo: float, hi: float, a0: float, a1: float) -> float:
	if lo < a0:
		return a0 - lo
	if hi > a1:
		return a1 - hi
	return 0.0


## Moves the origin so the floor is centred in `viewport_size` (zoom unchanged).
func center_floor(viewport_size: Vector2, width: int, height: int) -> void:
	origin = Vector2.ZERO
	var b := floor_bounds(width, height)
	origin = viewport_size * 0.5 - (b.position + b.size * 0.5)


## Top-left of a sprite image whose ground anchor (source px) must sit on `ground`.
## Source images are 2x, shown at zoom/2 (02 §E), so anchors scale by zoom / SOURCE_SCALE.
func sprite_top_left(ground: Vector2, anchor_px: Vector2) -> Vector2:
	return ground - anchor_px * (zoom / SOURCE_SCALE)
