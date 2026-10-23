extends Node2D
## Tile highlights drawn after the world (01 §2 SelectionOverlay): a light hover diamond
## and a stronger diamond for the selected tile.

const HOVER_FILL := Color(1.0, 0.85, 0.2, 0.30)
const HOVER_EDGE := Color(1.0, 0.85, 0.2, 0.95)
const SELECT_FILL := Color(0.36, 0.68, 0.99, 0.35)
const SELECT_EDGE := Color(0.36, 0.68, 0.99, 1.0)

var polygon: PackedVector2Array = PackedVector2Array()
var selected_polygon: PackedVector2Array = PackedVector2Array()


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


func _draw() -> void:
	_draw_diamond(polygon, HOVER_FILL, HOVER_EDGE, 2.0)
	_draw_diamond(selected_polygon, SELECT_FILL, SELECT_EDGE, 3.0)


func _draw_diamond(poly: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
	if poly.size() < 4:
		return
	draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, edge, width)
