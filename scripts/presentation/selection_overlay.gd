extends Node2D
## Draws the highlight of one tile diamond, after the world (01 §2 SelectionOverlay).

const FILL := Color(1.0, 0.85, 0.2, 0.30)
const EDGE := Color(1.0, 0.85, 0.2, 0.95)

var polygon: PackedVector2Array = PackedVector2Array()


func show_tile(diamond: PackedVector2Array) -> void:
	polygon = diamond
	queue_redraw()


func clear() -> void:
	polygon = PackedVector2Array()
	queue_redraw()


func _draw() -> void:
	if polygon.size() < 4:
		return
	draw_colored_polygon(polygon, FILL)
	var closed := polygon.duplicate()
	closed.append(polygon[0])
	draw_polyline(closed, EDGE, 2.0)
