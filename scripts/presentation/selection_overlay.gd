extends Node2D
## Tile highlights drawn after the world (01 §2 SelectionOverlay): hover diamond, selected
## diamond, and the placement ghost (occupied cells green/red, free access tiles yellow).

const HOVER_FILL := Color(1.0, 0.85, 0.2, 0.30)
const HOVER_EDGE := Color(1.0, 0.85, 0.2, 0.95)
const SELECT_FILL := Color(0.36, 0.68, 0.99, 0.35)
const SELECT_EDGE := Color(0.36, 0.68, 0.99, 1.0)
const GHOST_OK := Color(0.26, 0.78, 0.49, 0.55)
const GHOST_BAD := Color(0.93, 0.56, 0.56, 0.60)
const ACCESS_FILL := Color(1.0, 0.78, 0.45, 0.35)
const ACCESS_EDGE := Color(1.0, 0.78, 0.45, 1.0)
const QUEUE_FILL := Color(0.36, 0.68, 0.99, 0.30)
const QUEUE_EDGE := Color(0.36, 0.68, 0.99, 0.9)

var polygon: PackedVector2Array = PackedVector2Array()
var selected_polygon: PackedVector2Array = PackedVector2Array()
var ghost_cells: Array = []
var ghost_access: Array = []
var ghost_queue: Array = []
var ghost_valid: bool = false


func show_tile(diamond: PackedVector2Array) -> void:
	polygon = diamond
	queue_redraw()


func clear() -> void:
	polygon = PackedVector2Array()
	queue_redraw()


func show_selected(diamond: PackedVector2Array) -> void:
	selected_polygon = diamond
	queue_redraw()


func clear_selected() -> void:
	selected_polygon = PackedVector2Array()
	queue_redraw()


func show_ghost(cells: Array, access: Array, valid: bool, queue: Array = []) -> void:
	ghost_cells = cells
	ghost_access = access
	ghost_queue = queue
	ghost_valid = valid
	queue_redraw()


func clear_ghost() -> void:
	ghost_cells = []
	ghost_access = []
	ghost_queue = []
	queue_redraw()


func _draw() -> void:
	for poly in ghost_queue:
		_draw_diamond(poly, QUEUE_FILL, QUEUE_EDGE, 2.0)
	for poly in ghost_access:
		_draw_diamond(poly, ACCESS_FILL, ACCESS_EDGE, 2.0)
	for poly in ghost_cells:
		_draw_diamond(poly, GHOST_OK if ghost_valid else GHOST_BAD, GHOST_OK.lightened(0.3) if ghost_valid else GHOST_BAD.lightened(0.3), 2.0)
	_draw_diamond(polygon, HOVER_FILL, HOVER_EDGE, 2.0)
	_draw_diamond(selected_polygon, SELECT_FILL, SELECT_EDGE, 3.0)


func _draw_diamond(poly: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	if poly.size() < 4:
		return
	draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, edge, width)
