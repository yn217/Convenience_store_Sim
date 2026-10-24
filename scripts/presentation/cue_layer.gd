class_name CueLayer
extends Node2D
## Draws what CuePlayer holds, above everything in the store view (screen space of the view):
## toasts in the notification column (top right, under the HUD, left of the inspector), the "+¥" sales pop-ups
## above the register, register glow, door flash, confetti and the small pickup / empty-handed marks over customers.
## Read-only, except that a click on an error toast dismisses it (errors stay until then).

const TOAST_EDGE := {"error": Color("ff8a80"), "warning": Color("ffd54f"), "achievement": Color("ffc873"), "info": Color("90caf9")}
const TOAST_MARK := {"error": "‼", "warning": "★", "achievement": "◆", "info": "●"}
const TOAST_FONT := 17
const TOAST_MAX_WIDTH := 400.0
const TOAST_PAD := 32.0
const TOAST_GAP := 6.0
const TOAST_POP_SECONDS := 0.18
const TOAST_FADE_SECONDS := 0.3
const SALE_FONT := 20
const SALE_RISE := 40.0            # px the pop-up rises over its lifetime (0 under reduce_motion)
const SALE_CLEAR_BADGE := 34.0     # px above the badge's bottom edge where the sale text's baseline starts
const FALLBACK_TOP := 76.0
const FALLBACK_RIGHT := 12.0

var _world: Node2D
var _player: CuePlayer
var _column: Node   # FloatCards (group notification_column): where the toast column starts
## Toast pills, built once per level (UiTheme.toast_box); alpha is set per frame, no allocation.
var _toast_boxes: Dictionary = {}
## Screen rects of the toasts drawn last frame, for clicks (error toasts only).
var _toast_hits: Array[Dictionary] = []


func _ready() -> void:
	_world = get_parent()


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("cue_player") as CuePlayer
	if _column == null:
		_column = get_tree().get_first_node_in_group("notification_column")
	if _player != null and _player.has_motion():
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for hit in _toast_hits:
		if (hit["rect"] as Rect2).has_point(event.position) and _player != null:
			_player.dismiss_toast(hit["item"])
			_toast_hits.erase(hit)
			get_viewport().set_input_as_handled()
			queue_redraw()
			return


func _font() -> Font:
	var f: Font = ThemeDB.get_default_theme().default_font
	return f if f != null else ThemeDB.fallback_font


## Screen point of the queue badge of a register (the badge's bottom edge); the sale pop-up is placed relative to it.
func _sale_anchor(register_id: String) -> Vector2:
	for inst in _world.fixtures:
		if inst["instance_id"] == register_id:
			var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
			var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
			var cx := 0.0
			var cy := 0.0
			for c in cells:
				cx += c.x
				cy += c.y
			var n := float(maxi(cells.size(), 1))
			return _world.projection.world_to_screen(cx / n, cy / n, float(def["dimensions_m"]["height"]) + OverlayModel.QUEUE_BADGE_LIFT)
	return Vector2.ZERO


func _register_pos(register_id: String) -> Vector2:
	for inst in _world.fixtures:
		if inst["instance_id"] == register_id:
			return _world.projection.world_to_screen(inst["x"], inst["y"], 0.6)   # the till's body: the queue badge sits above the top
	return Vector2.ZERO


func _draw() -> void:
	if _player == null or _world.store_width <= 0:
		return
	var proj: IsoProjection = _world.projection
	var font := _font()
	var size := Vector2(_world.viewport_size())
	if _player.door_flash > 0.0:
		for t in _world.entrance_tiles:
			var seg := BackdropLayer.door_segment(t, _world.store_width, _world.store_height)
			draw_line(proj.world_to_screen(seg[0].x, seg[0].y), proj.world_to_screen(seg[1].x, seg[1].y), Color(1, 1, 0.6, minf(_player.door_flash / 0.35, 1.0)), 8.0 * maxf(proj.zoom, 0.75))
	for g in _player.glows:
		var p := _register_pos(g["register_id"])
		if p != Vector2.ZERO:
			var a: float = 0.55 * (1.0 - float(g["age"]) / maxf(float(g["ttl"]), 0.01))
			draw_circle(p, 26.0 * proj.zoom, Color(1.0, 0.95, 0.6, a))
	_draw_sales(font, proj)
	var presenter: Node2D = _world.get_node_or_null("ObjectSortRoot/FixturePresenter")
	var bubbles := _pick_bubbles(presenter, size)
	for m in _player.marks:
		var where := _customer_head(presenter, m["customer_id"])
		if where != Vector2.ZERO:
			if m["kind"] == "pick":
				if bubbles.has(m):
					_draw_pick_bubble(font, where, m)
			else:
				draw_string_outline(font, where + Vector2(-8, -8), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.8))
				draw_string(font, where + Vector2(-8, -8), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ff8a80"))
	for p in _player.particles:
		var pos := Vector2(p["pos"].x * size.x, p["pos"].y * size.y)
		draw_rect(Rect2(pos, Vector2(8, 5)), Color.from_hsv(p["hue"], 0.6, 1.0, 1.0 - p["age"] / p["ttl"]))
	_draw_toasts(font, size)


## Toasts stack downwards from the column top, right-aligned to the column edge, newest last.
func _draw_toasts(font: Font, size: Vector2) -> void:
	_toast_hits.clear()
	var top := float(_column.column_top) if _column != null else FALLBACK_TOP
	var right := size.x - (float(_column.column_right) if _column != null else FALLBACK_RIGHT)
	var y := top
	var reduce := _player.reduce_motion
	for t in _player.toasts:
		var level: String = t["level"]
		var achievement := level == "achievement"
		var text := "%s %s" % [TOAST_MARK[level], t["text"]]
		var ext := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TOAST_FONT)
		var w := minf(ext.x + TOAST_PAD, TOAST_MAX_WIDTH)
		var h := ext.y + 12.0
		var fade := 1.0 if reduce else clampf((float(t["ttl"]) - float(t["age"])) / TOAST_FADE_SECONDS, 0.0, 1.0)
		var pop := 1.0 if reduce else clampf(float(t["age"]) / TOAST_POP_SECONDS, 0.0, 1.0)
		var pop_scale := 0.9 + 0.1 * (1.0 - pow(1.0 - pop, 3.0))   # scale-in 0.9 -> 1.0, eased; no tween objects
		var alpha := fade * pop
		var box := _toast_box(level)
		var edge: Color = UiTheme.WARM if achievement else TOAST_EDGE[level]
		box.bg_color = Color(UiTheme.TOAST_BG, UiTheme.TOAST_BG.a * alpha)
		box.border_color = Color(edge, (1.0 if achievement else 0.7) * alpha)
		draw_set_transform(Vector2(right - w * 0.5, y + h * 0.5), 0.0, Vector2(pop_scale, pop_scale))
		draw_style_box(box, Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)))
		var ink: Color = UiTheme.WARM if achievement else Color.WHITE
		var baseline := Vector2(-w * 0.5 + 16.0, -h * 0.5 + (h - ext.y) * 0.5 + font.get_ascent(TOAST_FONT))
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, w - TOAST_PAD, TOAST_FONT, 3, Color(0, 0, 0, 0.6 * alpha))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, w - TOAST_PAD, TOAST_FONT, Color(ink, alpha))
		draw_set_transform(Vector2.ZERO)
		if level == "error":
			_toast_hits.append({"rect": Rect2(Vector2(right - w, y), Vector2(w, h)), "item": t})
		y += h + TOAST_GAP


## Pick cue: a small bubble over the head with the item's category icon and a tiny "+かご" that rises and fades.
## It is only the reservation moment (not a sale): the sale pop-up is drawn at the register on SALE_COMMITTED.
func _draw_pick_bubble(font: Font, where: Vector2, m: Dictionary) -> void:
	var ttl := maxf(float(m["ttl"]), 0.01)
	var k := clampf(float(m["age"]) / ttl, 0.0, 1.0)
	var alpha := 1.0 if _player.reduce_motion else 1.0 - k * 0.6
	var box := Rect2(where + Vector2(-14, -50), Vector2(28, 28))
	draw_rect(box, Color(1, 1, 1, 0.95 * alpha))
	draw_rect(box, Color(0, 0, 0, 0.6 * alpha), false, 1.5)
	var sku: Dictionary = _world.product_catalog.get_sku(String(m.get("sku_id", ""))) if _world.product_catalog != null else {}
	if not sku.is_empty():
		draw_texture_rect(ProductIcons.texture(sku, 24), Rect2(box.position + Vector2(2, 2), Vector2(24, 24)), false, Color(1, 1, 1, alpha))
	var at := where + Vector2(18, -40 - (0.0 if _player.reduce_motion else 10.0 * k))
	draw_string_outline(font, at, "+かご", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0, 0.8 * alpha))
	draw_string(font, at, "+かご", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 1.0, 0.75, alpha))


## At most MAX_PICK_BUBBLES pick bubbles on screen at once (#117 clutter): the selected customer first, then the figures
## nearest the middle of the store view. The others keep their timer and are not drawn.
const MAX_PICK_BUBBLES := 3


func _pick_bubbles(presenter: Node2D, size: Vector2) -> Array:
	var cand: Array = []
	for m in _player.marks:
		if m["kind"] != "pick":
			continue
		var where := _customer_head(presenter, m["customer_id"])
		if where == Vector2.ZERO:
			continue
		var selected: bool = _world.selected_customer != "" and m["customer_id"] == _world.selected_customer
		cand.append({"m": m, "d": -1.0 if selected else where.distance_to(size * 0.5)})
	cand.sort_custom(func(a, b): return a["d"] < b["d"])
	var out: Array = []
	for i in mini(cand.size(), MAX_PICK_BUBBLES):
		out.append(cand[i]["m"])
	return out


## Sales pop-ups: one "+¥" per register, rising and fading over its 0.8 s. Under reduce_motion it stays still.
func _draw_sales(font: Font, proj: IsoProjection) -> void:
	var still := _player.reduce_motion
	for f in _player.floats:
		var p := _sale_anchor(f["register_id"])
		if p == Vector2.ZERO:
			continue
		var k: float = float(f["age"]) / maxf(float(f["ttl"]), 0.01)
		# Starts above the "レジ待ち" badge (which sits on the same anchor) and rises from there, never over it.
		var at := p + Vector2(-20, -SALE_CLEAR_BADGE * proj.zoom - (0.0 if still else SALE_RISE * k * proj.zoom))
		var alpha := 1.0 if still else 1.0 - k
		draw_string_outline(font, at, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, SALE_FONT, 4, Color(0, 0, 0, 0.8 * alpha))
		draw_string(font, at, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, SALE_FONT, Color(1, 0.95, 0.5, alpha))


func _toast_box(level: String) -> StyleBoxFlat:
	if not _toast_boxes.has(level):
		_toast_boxes[level] = UiTheme.toast_box(TOAST_EDGE[level], level == "achievement")
	return _toast_boxes[level]


func _customer_head(presenter: Node2D, customer_id: String) -> Vector2:
	if presenter == null or not presenter._pos.has(customer_id):
		return Vector2.ZERO
	var pos: Vector2 = presenter._pos[customer_id]
	return _world.projection.world_to_screen(pos.x, pos.y, 1.9)
