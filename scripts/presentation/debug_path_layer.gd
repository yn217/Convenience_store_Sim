class_name DebugPathLayer
extends Node2D
## Debug overlay for customer paths (issue #26). Off by default and read-only: it draws nothing unless
## `enabled` (StoreWorld toggles it with F3, tools/capture_screen.gd with --debug-paths). For every customer:
## the cell it stands on (white), its next cell (green), the route the drawn figure still walks (magenta, a
## polyline through tile centres: from the shown position along the walked trail and the remaining path, so it
## only ever runs over walkable tiles), the shown position the presenter draws (red dot), a thin dashed LAG line
## from the shown position straight to the logical cell (a distance indicator only: a straight line in screen
## space is NOT a walking route and may cross shelves, so it is not a path), and the target fixture with its
## access tiles (yellow; the goal tile is ringed). Fixture footprints are outlined in cyan.

const FOOT_FILL := Color(0.30, 0.85, 1.00, 0.18)
const FOOT_EDGE := Color(0.30, 0.85, 1.00, 0.90)
const ACCESS := Color(1.00, 0.85, 0.20, 0.95)
const CUR := Color(1.00, 1.00, 1.00, 0.95)
const NEXT := Color(0.35, 1.00, 0.45, 0.95)
const PATH := Color(1.00, 0.35, 0.85, 0.90)
const SHOWN := Color(1.00, 0.20, 0.20, 0.95)
const LAG := Color(1.00, 0.20, 0.20, 0.55)   # dashed: the straight distance from the shown figure to its logical cell
const LABEL := Color(1.00, 1.00, 1.00, 0.95)

var enabled := false
var _world: Node2D = null
var _presenter: Node2D = null   # the FixturePresenter (customer_view() gives the shown position)


func attach(world: Node2D, presenter: Node2D) -> void:
	_world = world
	_presenter = presenter


func _process(_delta: float) -> void:
	if enabled and _world != null:
		queue_redraw()


func _draw() -> void:
	if not enabled or _world == null or _world.projection == null or _world.fixture_catalog == null:
		return
	var proj: IsoProjection = _world.projection
	var by_id := {}
	for inst in _world.fixtures:
		by_id[inst["instance_id"]] = inst
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		for c in StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"]):
			_cell_shape(proj, c, FOOT_FILL, FOOT_EDGE)
	for c in _world.customers:
		_draw_customer(proj, c, by_id)


func _draw_customer(proj: IsoProjection, c: Dictionary, by_id: Dictionary) -> void:
	var cur: Vector2i = c["tile"]
	var path: Array = c.get("path", [])
	var goal: Vector2i = path.back() if not path.is_empty() else cur
	var fixture_id: String = c.get("fixture_id", "")
	if fixture_id != "" and by_id.has(fixture_id):
		var inst: Dictionary = by_id[fixture_id]
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		for a in PlacementRules.access_candidates(def, inst["x"], inst["y"], inst["rotation"]):
			_cell_dot(proj, a, ACCESS)
	# The route the drawn figure still walks: from its shown position through the tile centres after it.
	var route: PackedVector2Array = _presenter.shown_route(c)
	var shown: Vector2 = _presenter.customer_view(c)["pos"]
	var shown_px := proj.world_to_screen(shown.x, shown.y)
	var pts := PackedVector2Array()
	if route.size() > 1:
		for p in route:
			pts.append(proj.world_to_screen(p.x, p.y))
	else:   # not tracked by the presenter (no shown walk): the simulation's own remaining path
		pts.append(proj.tile_center(cur))
		for p in path:
			pts.append(proj.tile_center(p))
	if pts.size() > 1:
		draw_polyline(pts, PATH, 2.0)
	_cell_shape(proj, cur, Color(CUR, 0.10), CUR)
	if not path.is_empty():
		_cell_dot(proj, path[0], NEXT)
	if goal != cur:
		draw_arc(proj.tile_center(goal), 9.0, 0.0, TAU, 16, ACCESS, 2.0)
	# Lag: a straight, dashed distance indicator from the shown position to the logical cell (not a route).
	var lag_px := proj.tile_center(cur)
	if shown_px.distance_to(lag_px) > 1.0:
		draw_dashed_line(shown_px, lag_px, LAG, 1.0, 4.0)
	draw_circle(shown_px, 3.5, SHOWN)
	var text := "%s %s %s" % [str(c["customer_id"]).right(5), c["phase"], fixture_id]
	draw_string(ThemeDB.fallback_font, shown_px + Vector2(6, -10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LABEL)


func _cell_shape(proj: IsoProjection, c: Vector2i, fill: Color, edge: Color) -> void:
	var corners := proj.tile_diamond(c)
	draw_colored_polygon(corners, fill)
	var closed := corners.duplicate()
	closed.append(corners[0])
	draw_polyline(closed, edge, 1.0)


func _cell_dot(proj: IsoProjection, c: Vector2i, color: Color) -> void:
	draw_circle(proj.tile_center(c), 3.0, color)
