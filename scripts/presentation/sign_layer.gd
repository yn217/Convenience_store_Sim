class_name SignLayer
extends Node2D
## Issue #61 (signs): a small code-drawn category board above each stocked fixture (e.g. おにぎり over the
## rice-ball case). Presentation only: it reads the snapshot through StoreWorld and never changes state or takes
## input. Hidden when zoomed far out (< MIN_ZOOM) and while an information overlay is on, so the layout and info
## overlays stay readable. The boards are rebuilt only when (revision, zoom, origin, fixture count) changes; a
## steady frame just replays the cached commands.

const _Presenter := preload("res://scripts/presentation/fixture_presenter.gd")

const LABELS := {
	"rice_ball": "おにぎり", "oden": "おでん", "instant_noodle": "カップ麺", "bread": "パン",
	"drink": "飲料", "snack": "おかし", "dessert": "デザート", "ice_cream": "アイス",
}
const MIN_ZOOM := 0.5
const TEXT_COLOR := Color.WHITE
const DARKEN := 0.45          ## board fill = category colour darkened by this amount
const BORDER_LIGHTEN := 0.25  ## 1 px border = category colour lightened by this amount
const CORNER_PX := 4.0
const LIFT_PX := 4.0          ## the board's centre sits this far above the fixture's top edge

var _world: Node2D
var _key: Array = []
var _commands: Array = []     ## [{"box": StyleBoxFlat, "rect": Rect2, "text": String, "pos": Vector2, "size": int}]


## Short Japanese label of a fixture: the first allowed category. "" for the register and unlabelled types.
static func label_for(def: Dictionary) -> String:
	var cats: Array = def.get("allowed_categories", [])
	if cats.is_empty():
		return ""
	return LABELS.get(cats[0], "")


## Font size of the board text in px: 12 * zoom, clamped to 9..16.
static func text_size(zoom: float) -> int:
	return clampi(roundi(12.0 * zoom), 9, 16)


## Board rectangle for a fixture whose screen bounds are `bounds`: horizontally centred on the bounds,
## vertically centred on its top edge, nudged a little above it.
static func board_rect(bounds: Rect2, text_width: float, zoom: float) -> Rect2:
	var size := text_size(zoom)
	var w := text_width + 12.0 * zoom
	var h := size * 1.4 + 4.0 * zoom
	var centre := Vector2(bounds.get_center().x, bounds.position.y - LIFT_PX * zoom)
	return Rect2(centre.x - w * 0.5, centre.y - h * 0.5, w, h)


func _ready() -> void:
	_world = get_parent()


func _draw() -> void:
	if _world == null or _world.store_width <= 0 or _world.fixture_catalog == null:
		return
	if _world.overlay_mode != OverlayModel.Mode.NORMAL or _world.projection.zoom < MIN_ZOOM:
		return
	_rebuild_if_stale()
	for cmd in _commands:
		draw_style_box(cmd["box"], cmd["rect"])
		draw_string(_font(), cmd["pos"], cmd["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, cmd["size"], TEXT_COLOR)


func _font() -> Font:
	var theme_font: Font = ThemeDB.get_default_theme().default_font
	return theme_font if theme_font != null else ThemeDB.fallback_font


func _rebuild_if_stale() -> void:
	var proj: IsoProjection = _world.projection
	var key := [_world.revision, proj.zoom, proj.origin, _world.fixtures.size()]
	if key == _key:
		return
	_key = key
	_commands.clear()
	var font := _font()
	var size := text_size(proj.zoom)
	var pad_x := 6.0 * proj.zoom
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var text := label_for(def)
		if text == "":
			continue
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var bounds := OverlayModel.fixture_bounds(proj, cells, float(def["dimensions_m"]["height"]))
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var rect := board_rect(bounds, text_width, proj.zoom)
		var base: Color = _Presenter.CATEGORY_COLOR.get(def["allowed_categories"][0], _Presenter.REGISTER_COLOR)
		var box := StyleBoxFlat.new()
		box.bg_color = base.darkened(DARKEN)
		box.border_color = base.lightened(BORDER_LIGHTEN)
		box.set_border_width_all(1)
		box.set_corner_radius_all(roundi(CORNER_PX * proj.zoom))
		var baseline := rect.position.y + (rect.size.y - font.get_height(size)) * 0.5 + font.get_ascent(size)
		_commands.append({"box": box, "rect": rect, "text": text, "pos": Vector2(rect.position.x + pad_x, baseline), "size": size})
