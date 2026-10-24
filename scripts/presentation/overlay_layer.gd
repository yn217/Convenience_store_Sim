class_name OverlayLayer
extends Node2D
## Information overlays above the objects (#24), switched with the O key or the mode buttons:
##  LAYOUT - tile grid, blocked tiles (crossed out), customer-side tiles of every fixture (arrow + word), entrance.
##  INFO   - a badge per fixture: stock icon + word (売切 / 残少 / 在庫), and today's units sold.
## Nothing here is colour-only: every mark has a glyph or a word. Read-only; it never changes state.

const GRID := Color(1, 1, 1, 0.30)
const BLOCK := Color(0.10, 0.10, 0.12, 0.65)
const ACCESS_FILL := Color(1.0, 0.78, 0.45, 0.30)
const ACCESS_EDGE := Color(1.0, 0.78, 0.45, 0.95)
const BADGE_BG := Color(0.08, 0.10, 0.14, 0.85)
const QUEUE_FULL := Color("ffb300")   # amber: the register's line is at its maximum
const QUEUE_OVERFLOW := Color("ff5252")   # red: customers outside the line
const LEVEL_COLOR := {"empty": Color("ff8a80"), "low": Color("ffd54f"), "ok": Color("9ccc65"), "register": Color("90caf9"), "none": Color("cfd8dc")}

var _world: Node2D


func _ready() -> void:
	_world = get_parent()


func _font() -> Font:
	var theme_font: Font = ThemeDB.get_default_theme().default_font
	return theme_font if theme_font != null else ThemeDB.fallback_font


func _process(_delta: float) -> void:
	if _world != null and (_world.overlay_mode != OverlayModel.Mode.NORMAL or _world.selected_customer != "" or not _world.customers.is_empty()):
		queue_redraw()


func _draw() -> void:
	if _world == null or _world.store_width <= 0 or _world.fixture_catalog == null:
		return
	_draw_selected_customer()
	_draw_queue_badges()
	match _world.overlay_mode:
		OverlayModel.Mode.LAYOUT:
			_draw_layout()
		OverlayModel.Mode.INFO:
			_draw_info()


## Ring + word under the picked customer, visible even when a fixture stands in front.
func _draw_selected_customer() -> void:
	if _world.selected_customer == "":
		return
	var presenter: Node2D = _world.get_node_or_null("ObjectSortRoot/FixturePresenter")
	for c in _world.customers:
		if c["customer_id"] != _world.selected_customer:
			continue
		var proj: IsoProjection = _world.projection
		var pos: Vector2 = presenter._pos.get(c["customer_id"], presenter.target_pos(c))
		var foot := proj.world_to_screen(pos.x, pos.y)
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(foot + Vector2(cos(a) * 26.0, sin(a) * 13.0) * proj.zoom)
		draw_polyline(pts, Color("5cc8ff"), 3.0)
		_label(_font(), foot + Vector2(0, 26.0 * proj.zoom), "選択中", int(round(13.0 * maxf(proj.zoom, 0.8))))
		# #141: where it is heading — the route ahead and a ring on the goal tile.
		var route: PackedVector2Array = presenter.shown_route(c)
		if route.size() >= 2:
			var screen := PackedVector2Array()
			for p in route:
				screen.append(proj.world_to_screen(p.x, p.y))
			draw_polyline(screen, Color(0.36, 0.78, 1.0, 0.75), 2.5 * maxf(proj.zoom, 0.8))
			var goal := screen[screen.size() - 1]
			var ring := PackedVector2Array()
			for i in 17:
				var a := TAU * i / 16.0
				ring.append(goal + Vector2(cos(a) * 18.0, sin(a) * 9.0) * proj.zoom)
			draw_polyline(ring, Color(1.0, 0.85, 0.3, 0.9), 2.5)


func _cells(inst: Dictionary, def: Dictionary) -> Array[Vector2i]:
	return StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])


## Point above a fixture's footprint centre, `lift` metres over its top (badges sit here).
func _top_anchor(inst: Dictionary, def: Dictionary, lift: float) -> Vector2:
	var cells := _cells(inst, def)
	var cx := 0.0
	var cy := 0.0
	for c in cells:
		cx += c.x
		cy += c.y
	return _world.projection.world_to_screen(cx / cells.size(), cy / cells.size(), float(def["dimensions_m"]["height"]) + lift)


## "レジ待ち N人 ＋列外M人" above each register with at least one customer in line (slots or overflow).
## Amber when the slots are full, red when customers are outside the line.
func _draw_queue_badges() -> void:
	if _world.overlay_mode == OverlayModel.Mode.INFO:
		return   # the info mode shows the same counts in the register's own badge
	var queues := OverlayModel.register_queues(_world.customers)
	if queues.is_empty():
		return
	var font := _font()
	var size := int(round(13.0 * maxf(_world.projection.zoom, 0.8)))
	for inst in _world.fixtures:
		var q: Dictionary = queues.get(inst["instance_id"], {})
		if q.is_empty() or OverlayModel.line_size(q) < 1:
			continue
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var accent := LEVEL_COLOR["register"]
		match OverlayModel.queue_badge_state(int(q["queued"]), int(q["overflow"]), AccessService.QUEUE_MAX):
			"overflow":
				accent = QUEUE_OVERFLOW
			"full":
				accent = QUEUE_FULL
		_badge(font, _top_anchor(inst, def, OverlayModel.QUEUE_BADGE_LIFT), OverlayModel.queue_badge_text(int(q["queued"]), int(q["overflow"])), size, accent)


func _draw_layout() -> void:
	var proj: IsoProjection = _world.projection
	for y in _world.store_height:
		for x in _world.store_width:
			var d := proj.tile_diamond(Vector2i(x, y))
			var closed := d.duplicate()
			closed.append(d[0])
			draw_polyline(closed, GRID, 1.0)
	var font := _font()
	var size := int(round(13.0 * maxf(proj.zoom, 0.8)))
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var cells := _cells(inst, def)
		for c in cells:
			var d := proj.tile_diamond(c)
			draw_line(d[0], d[2], BLOCK, 2.0)   # crossed-out tile: not walkable
			draw_line(d[1], d[3], BLOCK, 2.0)
		if proj.zoom >= 1.0:
			_label(font, proj.world_to_screen(cells[0].x, cells[0].y), "通れない", size)
		for a in OverlayModel.access_cells(cells, def["access_edges"], int(inst["rotation"]), _world.store_width, _world.store_height):
			var ad := proj.tile_diamond(a)
			draw_colored_polygon(ad, ACCESS_FILL)
			var closed := ad.duplicate()
			closed.append(ad[0])
			draw_polyline(closed, ACCESS_EDGE, 2.0)
			var mid := proj.world_to_screen(a.x, a.y)
			draw_line(mid + Vector2(-8, 3), mid + Vector2(0, -5), ACCESS_EDGE, 2.0)   # chevron: "stand here"
			draw_line(mid + Vector2(0, -5), mid + Vector2(8, 3), ACCESS_EDGE, 2.0)
			if proj.zoom >= 1.0:
				_label(font, mid + Vector2(0, 14.0 * proj.zoom), "客側", size)
	for t in _world.entrance_tiles:
		var p := proj.world_to_screen(t.x, t.y)
		_label(font, p, "入口", size)


func _draw_info() -> void:
	var proj: IsoProjection = _world.projection
	var font := _font()
	var size := int(round(14.0 * maxf(proj.zoom, 0.8)))
	var queues := OverlayModel.register_queues(_world.customers)
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		if AccessService.is_register(def):
			var q: Dictionary = queues.get(inst["instance_id"], {})
			var est := OverlayModel.estimated_wait_minutes(q, _world.checkout_duration_sec)
			_badge(font, _top_anchor(inst, def, 0.25), OverlayModel.register_info_text(q, est), size, LEVEL_COLOR["register"])
			continue
		var status := OverlayModel.stock_status(def, _world.shelf_stock.get(inst["instance_id"], {}))
		if status["text"] == "":
			continue
		var pos := _top_anchor(inst, def, 0.25)
		var line := "%s %s" % [status["icon"], status["text"]]
		if not def["shelf_slots"].is_empty():
			line += "  " + OverlayModel.sales_text(int(_world.fixture_sales.get(inst["instance_id"], 0)))
		_badge(font, pos, line, size, LEVEL_COLOR[status["level"]])


func _label(font: Font, pos: Vector2, text: String, size: int) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _badge(font: Font, pos: Vector2, text: String, size: int, accent: Color) -> void:
	var ext := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var r := Rect2(pos - Vector2(ext.x * 0.5 + 6.0, ext.y + 2.0), ext + Vector2(12.0, 8.0))
	draw_rect(r, BADGE_BG)
	draw_rect(r, accent, false, 2.0)
	draw_string(font, r.position + Vector2(6.0, ext.y - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
