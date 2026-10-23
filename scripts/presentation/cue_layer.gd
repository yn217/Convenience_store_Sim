class_name CueLayer
extends Node2D
## Draws what CuePlayer holds, above everything in the store view (screen space of the view):
## toasts (top centre), "+¥" floats above the register, register glow, door flash, confetti and
## the small pickup / empty-handed marks over customers. Read-only.

const TOAST_BG := Color(0.08, 0.10, 0.14, 0.88)
const PRIORITY_EDGE := {"critical": Color("ff8a80"), "important": Color("ffd54f"), "normal": Color("90caf9"), "ambient": Color("b0bec5")}
const PRIORITY_MARK := {"critical": "‼", "important": "★", "normal": "●", "ambient": "・"}

var _world: Node2D
var _player: CuePlayer


func _ready() -> void:
	_world = get_parent()


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("cue_player") as CuePlayer
	if _player != null and _player.has_motion():
		queue_redraw()


func _font() -> Font:
	var f: Font = ThemeDB.get_default_theme().default_font
	return f if f != null else ThemeDB.fallback_font


func _register_pos(register_id: String) -> Vector2:
	for inst in _world.fixtures:
		if inst["instance_id"] == register_id:
			return _world.projection.world_to_screen(inst["x"], inst["y"], 1.35)
	return Vector2.ZERO


func _draw() -> void:
	if _player == null or _world.store_width <= 0:
		return
	var proj: IsoProjection = _world.projection
	var font := _font()
	var size := Vector2(_world.viewport_size())
	if _player.door_flash > 0.0:
		for t in _world.entrance_tiles:
			draw_line(proj.world_to_screen(-0.5, t.y - 0.5), proj.world_to_screen(-0.5, t.y + 0.5), Color(1, 1, 0.6, minf(_player.door_flash / 0.35, 1.0)), 8.0 * maxf(proj.zoom, 0.75))
	for g in _player.glows:
		var p := _register_pos(g["register_id"])
		if p != Vector2.ZERO:
			var a: float = 0.55 * (1.0 - float(g["age"]) / maxf(float(g["ttl"]), 0.01))
			draw_circle(p, 26.0 * proj.zoom, Color(1.0, 0.95, 0.6, a))
	for f in _player.floats:
		var p := _register_pos(f["register_id"])
		if p != Vector2.ZERO:
			var k: float = f["age"] / maxf(f["ttl"], 0.01)
			var at := p + Vector2(-20, -50.0 * k * proj.zoom)
			draw_string_outline(font, at, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.8))
			draw_string(font, at, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.5, 1.0 - k * 0.6))
	var presenter: Node2D = _world.get_node_or_null("ObjectSortRoot/FixturePresenter")
	for m in _player.marks:
		var where := _customer_head(presenter, m["customer_id"])
		if where != Vector2.ZERO:
			if m["kind"] == "pick":
				draw_rect(Rect2(where + Vector2(-6, -20), Vector2(12, 12)), Color("e8a87c"))
				draw_rect(Rect2(where + Vector2(-6, -20), Vector2(12, 12)), Color(0, 0, 0, 0.6), false, 1.5)
			else:
				draw_string_outline(font, where + Vector2(-8, -8), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, 0.8))
				draw_string(font, where + Vector2(-8, -8), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ff8a80"))
	for p in _player.particles:
		var pos := Vector2(p["pos"].x * size.x, p["pos"].y * size.y)
		draw_rect(Rect2(pos, Vector2(8, 5)), Color.from_hsv(p["hue"], 0.6, 1.0, 1.0 - p["age"] / p["ttl"]))
	var y := 14.0
	for t in _player.toasts:
		var text := "%s %s" % [PRIORITY_MARK[t["priority"]], t["text"]]
		var ext := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var r := Rect2(Vector2((size.x - ext.x) * 0.5 - 12.0, y), ext + Vector2(24.0, 12.0))
		var fade := 1.0 if _player.reduce_motion else clampf((t["ttl"] - t["age"]) / 0.3, 0.0, 1.0)
		draw_rect(r, Color(TOAST_BG, TOAST_BG.a * fade))
		draw_rect(r, Color(PRIORITY_EDGE[t["priority"]], fade), false, 2.0)
		draw_string(font, r.position + Vector2(12.0, ext.y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, fade))
		y += r.size.y + 6.0


func _customer_head(presenter: Node2D, customer_id: String) -> Vector2:
	if presenter == null or not presenter._pos.has(customer_id):
		return Vector2.ZERO
	var pos: Vector2 = presenter._pos[customer_id]
	return _world.projection.world_to_screen(pos.x, pos.y, 1.9)
