class_name MapView
extends Control
## Area map drawing (issue #150): the town of a WorldMap file drawn in code — zones, roads, railway, facility pins and
## store sites — fitted to the control, then zoomed (wheel, about the cursor, ZOOM_MIN..ZOOM_MAX) and panned (drag).
## Clicking a site emits plot_clicked; the panel around it (BusinessController) shows the site and sends SET_SITE.
## With forecast_hour >= 0 every site that can be picked carries a disc sized by its forecast visitors in that hour
## (WorldMap.forecast_by_hour: a forecast, labelled as such). Presentation only.

signal plot_clicked(plot_id: String)

const ZOOM_MIN := 1.0
const ZOOM_MAX := 3.0
const ZOOM_STEP := 1.15
const DRAG_PX := 6.0          # a press that moves further than this pans instead of clicking
const FORECAST_COLOR := Color(0.18, 0.43, 0.71, 0.35)
const FORECAST_MAX_RADIUS := 34.0

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
var zoom := 1.0
var pan := Vector2.ZERO          # extra offset in pixels after the fit
var forecast_hour := -1         # -1: no forecast layer
var _forecast: Dictionary = {}  # plot id -> Array[float] (24 hours)
var _map: Dictionary = {}
var _background: Texture2D = null
var rivals: Array = []   # #129: rival stores {map_id, x, y, name}
var _press := Vector2(-1, -1)
var _dragging := false


func _init() -> void:
	clip_contents = true   # zoomed in, the town stays inside the view


func set_map(id: String) -> void:
	map_id = id
	_map = WorldMap.load_map(id)
	_background = load(WorldMap.BACKGROUND[id]) if WorldMap.BACKGROUND.has(id) else null
	_forecast.clear()
	selected = ""
	reset_view()


func set_selected(plot_id: String) -> void:
	selected = plot_id
	queue_redraw()


## Shows the forecast discs for `hour` (-1 hides them); forecasts are computed once per map.
func set_forecast_hour(hour: int, balance: Dictionary) -> void:
	forecast_hour = hour
	if _forecast.is_empty() and hour >= 0:
		for p in _map.get("plots", []):
			if WorldMap.pickable(p):
				_forecast[p["id"]] = WorldMap.forecast_by_hour(balance, map_id, p["id"])
	queue_redraw()


## Zooms by `factor` keeping the map point under `at` (local pixels) where it is.
func zoom_at(at: Vector2, factor: float) -> void:
	var before := zoom
	zoom = clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var k := zoom / before
	var origin := _fit_offset() + pan
	pan = (at - (at - origin) * k) - _fit_offset()
	_clamp_pan()
	queue_redraw()


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()


## Keeps some of the map on screen.
func _clamp_pan() -> void:
	var span := _map_size() * _fit_scale() * zoom
	var lo := Vector2(size.x * 0.25, size.y * 0.25) - span - _fit_offset()
	var hi := Vector2(size.x * 0.75, size.y * 0.75) - _fit_offset()
	pan = pan.clamp(lo, hi)


func _map_size() -> Vector2:
	return WorldMap.map_size(map_id) if not _map.is_empty() else Vector2(1000, 680)


func _fit_scale() -> float:
	var m := _map_size()
	return minf(size.x / m.x, size.y / m.y)


func _fit_offset() -> Vector2:
	return (size - _map_size() * _fit_scale()) * 0.5


## Map units -> local pixels (fitted with its aspect ratio, then zoomed and panned).
func to_screen(x: float, y: float) -> Vector2:
	return _fit_offset() + pan + Vector2(x, y) * _scale()


func _scale() -> float:
	return _fit_scale() * zoom


## The site under a local position, or "".
func plot_at(pos: Vector2) -> String:
	for p in _map.get("plots", []):
		if to_screen(float(p["x"]), float(p["y"])).distance_to(pos) <= HIT_RADIUS:
			return String(p["id"])
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_at(event.position, ZOOM_STEP)
					accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_at(event.position, 1.0 / ZOOM_STEP)
					accept_event()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_press = event.position
					_dragging = false
				else:
					if not _dragging:
						var id := plot_at(event.position)
						if id != "":
							plot_clicked.emit(id)
					_press = Vector2(-1, -1)
					_dragging = false
				accept_event()
	elif event is InputEventMouseMotion and _press.x >= 0.0:
		if not _dragging and event.position.distance_to(_press) > DRAG_PX:
			_dragging = true
		if _dragging:
			pan += event.relative
			_clamp_pan()
			queue_redraw()
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), WATER)
	if _map.is_empty():
		return
	var k := _scale()
	if _background != null:
		draw_texture_rect(_background, Rect2(to_screen(0, 0), _map_size() * k), false)
	else:
		draw_rect(Rect2(to_screen(0, 0), _map_size() * k), LAND)
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
	for q in ([] if bool(_map.get("labels_baked", false)) else _map.get("pois", [])):   # baked into the picture
		var c := to_screen(float(q["x"]), float(q["y"]))
		draw_circle(c, PIN_RADIUS, POI_COLORS.get(q["type"], Color("8a949e")))
		draw_arc(c, PIN_RADIUS, 0.0, TAU, 16, Color.WHITE, 1.5)
		if _background != null:   # on a picture: white text with a dark edge
			draw_string_outline(font, c + Vector2(PIN_RADIUS + 2.0, 4.0), String(q["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color("1b232a"))
			draw_string(font, c + Vector2(PIN_RADIUS + 2.0, 4.0), String(q["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		else:
			draw_string(font, c + Vector2(PIN_RADIUS + 2.0, 4.0), String(q["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("33404a"))
	if forecast_hour >= 0:
		var peak := 0.0
		for id in _forecast:
			for v in _forecast[id]:
				peak = maxf(peak, float(v))
		for id in _forecast:
			var p := WorldMap.plot(map_id, id)
			var v := float(_forecast[id][forecast_hour])
			if peak > 0.0 and v > 0.0:
				draw_circle(to_screen(float(p["x"]), float(p["y"])), PLOT_RADIUS + FORECAST_MAX_RADIUS * sqrt(v / peak), FORECAST_COLOR)
	for r in rivals:   # #129: rival stores, a red marker with 競
		if r.get("map_id", "") == map_id:
			var rc := to_screen(float(r["x"]), float(r["y"]))
			draw_circle(rc, PLOT_RADIUS + 3.0, Color("d64545"))
			draw_arc(rc, PLOT_RADIUS + 3.0, 0.0, TAU, 20, Color.WHITE, 2.0)
			draw_string(ThemeDB.fallback_font, rc + Vector2(-6.0, 5.0), "競", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	for p in _map.get("plots", []):
		var c := to_screen(float(p["x"]), float(p["y"]))
		var status := WorldMap.plot_status(p)
		var fill := Color("f2c94c") if status == "available" else (Color("d64545") if status == "rival" else Color("9aa3ab"))
		if String(p["id"]) == selected:
			draw_circle(c, PLOT_RADIUS + 5.0, Color(1, 1, 1, 0.85))
		if String(p["id"]) == current:
			draw_arc(c, PLOT_RADIUS + 8.0, 0.0, TAU, 24, Color("2f6db5"), 3.0)
		draw_circle(c, PLOT_RADIUS, fill)
		draw_arc(c, PLOT_RADIUS, 0.0, TAU, 20, Color("2b3640"), 2.0)
		var label := "店" if status == "rival" else String(p["id"]).right(1)
		draw_string(font, c + Vector2(-4.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("1b232a"))
