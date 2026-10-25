class_name MapView
extends Control
## Area map drawing (issue #150 phase 1): the town of a WorldMap file drawn in code — zones, roads, railway,
## facility pins and store sites — scaled to fit the control. Clicking a site emits plot_clicked; the panel around it
## (BusinessController) shows the site and sends SET_SITE. Presentation only.

signal plot_clicked(plot_id: String)

const PIN_RADIUS := 7.0
const PLOT_RADIUS := 13.0
const HIT_RADIUS := 18.0
const LAND := Color("e8efe4")
const WATER := Color("16324a")
const ROAD := Color("ffffff")
const ROAD_EDGE := Color("b9c4bb")
const RAIL := Color("5a6470")
const ZONE_COLORS := {
	"station": Color(0.30, 0.55, 0.95, 0.16), "school": Color(0.95, 0.75, 0.25, 0.18), "office": Color(0.55, 0.45, 0.85, 0.16),
	"residential": Color(0.35, 0.75, 0.45, 0.18), "tourism": Color(0.95, 0.45, 0.55, 0.16),
}
const POI_COLORS := {
	"station": Color("3a7bd5"), "bus_terminal": Color("3a7bd5"), "school": Color("e0a020"), "university": Color("e0a020"),
	"office": Color("7a5cc8"), "residential": Color("3f9f5a"), "hotel": Color("d0567a"), "tourism": Color("e0607a"),
	"event_venue": Color("c86c2c"), "hospital": Color("d64545"), "logistics": Color("6b7480"), "market": Color("4aa38a"),
	"shopping": Color("c89a2c"), "parking": Color("8a949e"), "road_hub": Color("8a949e"),
}

var map_id := ""
var selected := ""
var current := ""      # the store's site (drawn with a ring)
var _map: Dictionary = {}


func set_map(id: String) -> void:
	map_id = id
	_map = WorldMap.load_map(id)
	queue_redraw()


func set_selected(plot_id: String) -> void:
	selected = plot_id
	queue_redraw()


## Map units -> local pixels (the map keeps its aspect ratio, centred).
func to_screen(x: float, y: float) -> Vector2:
	var cs: Dictionary = _map.get("coordinate_system", {"width": 1000, "height": 680})
	var w := float(cs.get("width", 1000))
	var h := float(cs.get("height", 680))
	var k := minf(size.x / w, size.y / h)
	var off := (size - Vector2(w, h) * k) * 0.5
	return off + Vector2(x, y) * k


func _scale() -> float:
	var cs: Dictionary = _map.get("coordinate_system", {"width": 1000, "height": 680})
	return minf(size.x / float(cs.get("width", 1000)), size.y / float(cs.get("height", 680)))


## The site under a local position, or "".
func plot_at(pos: Vector2) -> String:
	for p in _map.get("plots", []):
		if to_screen(float(p["x"]), float(p["y"])).distance_to(pos) <= HIT_RADIUS:
			return String(p["id"])
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := plot_at(event.position)
		if id != "":
			plot_clicked.emit(id)
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)
	if _map.is_empty():
		return
	var cs: Dictionary = _map["coordinate_system"]
	var k := _scale()
	draw_rect(Rect2(to_screen(0, 0), Vector2(float(cs["width"]), float(cs["height"])) * k), LAND)
	var font := ThemeDB.fallback_font
	var features: Dictionary = _map.get("features", {})
	for z in features.get("zones", []):
		draw_circle(to_screen(float(z["center"][0]), float(z["center"][1])), float(z["radius"]) * k, ZONE_COLORS.get(z["type"], Color(0, 0, 0, 0.08)))
	for r in features.get("roads", []):
		var pts := PackedVector2Array((r["points"] as Array).map(func(p): return to_screen(float(p[0]), float(p[1]))))
		draw_polyline(pts, ROAD_EDGE, (float(r["width"]) + 4.0) * k)
		draw_polyline(pts, ROAD, float(r["width"]) * k)
	for r in features.get("railways", []):
		var pts := PackedVector2Array((r["points"] as Array).map(func(p): return to_screen(float(p[0]), float(p[1]))))
		draw_polyline(pts, RAIL, 5.0 * k + 1.0)
		draw_dashed_line(pts[0], pts[pts.size() - 1], Color.WHITE, 2.0 * k + 0.5, 10.0 * k + 2.0)
	for q in _map.get("pois", []):
		var c := to_screen(float(q["x"]), float(q["y"]))
		draw_circle(c, PIN_RADIUS, POI_COLORS.get(q["type"], Color("8a949e")))
		draw_arc(c, PIN_RADIUS, 0.0, TAU, 16, Color.WHITE, 1.5)
		draw_string(font, c + Vector2(PIN_RADIUS + 2.0, 4.0), String(q["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("33404a"))
	for p in _map.get("plots", []):
		var c := to_screen(float(p["x"]), float(p["y"]))
		var status := String(p["status"])
		var fill := Color("f2c94c") if status == "available" else (Color("d64545") if status == "rival" else Color("9aa3ab"))
		if String(p["id"]) == selected:
			draw_circle(c, PLOT_RADIUS + 5.0, Color(1, 1, 1, 0.85))
		if String(p["id"]) == current:
			draw_arc(c, PLOT_RADIUS + 8.0, 0.0, TAU, 24, Color("2f6db5"), 3.0)
		draw_circle(c, PLOT_RADIUS, fill)
		draw_arc(c, PLOT_RADIUS, 0.0, TAU, 20, Color("2b3640"), 2.0)
		var label := "店" if status == "rival" else String(p["id"]).right(1)
		draw_string(font, c + Vector2(-4.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("1b232a"))
