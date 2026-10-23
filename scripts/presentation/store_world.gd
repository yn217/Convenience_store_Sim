extends Node2D
## Read-only presenter of the store (01 §2): floor, perimeter edge walls, west entrance
## and the hovered-tile highlight. Fixtures/customers are added by later issues.

const FLOOR_A := Color(0.80, 0.80, 0.76)
const FLOOR_B := Color(0.74, 0.74, 0.70)
const WALL := Color(0.25, 0.25, 0.28)
const DOOR := Color(0.25, 0.60, 0.85)
const OUTSIDE := Color(0.55, 0.62, 0.50)

var store_width: int = 0
var store_height: int = 0
var revision: int = -1
var entrance_tiles: Array[Vector2i] = []
var projection := IsoProjection.new()
var hover_tile := Vector2i(-1, -1)

@onready var _selection: Node2D = $SelectionOverlay


func _ready() -> void:
	get_viewport().size_changed.connect(_recenter)


func apply_snapshot(snapshot: Dictionary) -> void:
	store_width = int(snapshot["store_width"])
	store_height = int(snapshot["store_height"])
	revision = int(snapshot["revision"])
	entrance_tiles.clear()
	for t in snapshot.get("entrance_tiles", []):
		entrance_tiles.append(t)
	_recenter()


func tile_count() -> int:
	return store_width * store_height


func in_store(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < store_width and c.y < store_height


## Highlights the store tile under `screen_pos` (world-node local coordinates).
## Returns the hovered tile, or (-1,-1) when the point is outside the floor.
func set_hover_screen(screen_pos: Vector2) -> Vector2i:
	var c := projection.screen_to_tile(screen_pos)
	hover_tile = c if in_store(c) else Vector2i(-1, -1)
	if _selection != null:
		if hover_tile.x < 0:
			_selection.clear()
		else:
			_selection.show_tile(projection.tile_diamond(hover_tile))
	return hover_tile


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_hover_screen(get_local_mouse_position())


func _recenter() -> void:
	if store_width <= 0:
		return
	projection.center_floor(get_viewport_rect().size, store_width, store_height)
	queue_redraw()


func _draw() -> void:
	if store_width <= 0:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), OUTSIDE)
	for y in store_height:
		for x in store_width:
			var c := Vector2i(x, y)
			draw_colored_polygon(projection.tile_diamond(c), FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
	_draw_perimeter()


## Walls are edges of the outer cells (they never occupy a cell); the west entrance
## tiles are drawn as door segments on the x = -0.5 edge.
func _draw_perimeter() -> void:
	var w := store_width - 0.5
	var h := store_height - 0.5
	var corners := [
		projection.world_to_screen(-0.5, -0.5), projection.world_to_screen(w, -0.5),
		projection.world_to_screen(w, h), projection.world_to_screen(-0.5, h),
	]
	for i in 4:
		draw_line(corners[i], corners[(i + 1) % 4], WALL, 4.0)
	for t in entrance_tiles:
		draw_line(projection.world_to_screen(-0.5, t.y - 0.5), projection.world_to_screen(-0.5, t.y + 0.5), DOOR, 6.0)
