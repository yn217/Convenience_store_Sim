class_name SignLayer
extends Node2D
## Issue #61 (signs), redrawn for mockup #105 B6: a small rounded pill above each stocked fixture (e.g. おにぎり over the
## rice-ball case) with the category icon on its left. Presentation only: it reads the snapshot through StoreWorld and
## never changes state or takes input. Hidden when zoomed far out (< MIN_ZOOM) and while an information overlay is on,
## so the layout and info overlays stay readable. The pills are rebuilt only when (revision, zoom, origin, fixture
## count) changes; a steady frame just replays the cached commands.

const _Presenter := preload("res://scripts/presentation/fixture_presenter.gd")

const LABELS := {
	"rice_ball": "おにぎり", "oden": "おでん", "instant_noodle": "カップ麺", "bread": "パン",
	"drink": "飲料", "snack": "おかし", "dessert": "デザート", "ice_cream": "アイス",
	"bento": "弁当", "daily_fresh": "野菜・日配", "coffee": "コーヒー",
	"capsule_toy": "カプセルトイ",
	"daily_goods": "日用品", "hygiene": "衛生用品",
	"soft_serve": "ソフトクリーム", "frappe": "フラッペ",
	"bakery": "焼きたてパン", "pizza": "ピザ",
}
## Category icon (UiIcons name) shown on the left of the pill.
const ICONS := {
	"rice_ball": "onigiri", "oden": "bowl", "instant_noodle": "bowl", "bread": "bread",
	"drink": "drink", "snack": "bag", "dessert": "cake", "ice_cream": "snowflake",
	"bento": "box", "daily_fresh": "leaf", "coffee": "drop",
	"capsule_toy": "star",
	"daily_goods": "bag", "hygiene": "heart",
	"soft_serve": "snowflake", "frappe": "drink",
	"bakery": "bread", "pizza": "sun",
}
## The sign over a register nobody staffs (#113): a grey pill, no icon.
const CLOSED_TEXT := "休止中"
const CLOSED_COLOR := Color("5b6470")
const MIN_ZOOM := 0.5
const TEXT_COLOR := Color.WHITE
const DARKEN := 0.25          ## pill fill = category colour darkened by this amount (lighter than before: readable icon)
const BORDER_LIGHTEN := 0.35  ## 1 px border = category colour lightened by this amount
const LIFT_PX := 4.0          ## the pill's centre sits this far above the fixture's top edge
const ICON_RATIO := 0.7       ## icon size as a share of the pill height
const PAD_PX := 8.0           ## horizontal padding at zoom 1
const GAP_PX := 4.0           ## gap between icon and text at zoom 1

var _world: Node2D
var _key: Array = []
var _commands: Array = []     ## [{"box": StyleBoxFlat, "rect": Rect2, "text": String, "pos": Vector2, "size": int, "icon": Texture2D, "icon_rect": Rect2}]


## Short Japanese label of a fixture: the first allowed category. "" for the register and unlabelled types.
static func label_for(def: Dictionary) -> String:
	var cats: Array = def.get("allowed_categories", [])
	if cats.is_empty():
		return ""
	return LABELS.get(cats[0], "")


## Icon name of a fixture's first allowed category, or "" when it has none.
static func icon_for(def: Dictionary) -> String:
	var cats: Array = def.get("allowed_categories", [])
	if cats.is_empty():
		return ""
	return ICONS.get(cats[0], "")


## Font size of the pill text in px: 12 * zoom, clamped to 9..16.
static func text_size(zoom: float) -> int:
	return clampi(roundi(12.0 * zoom), 9, 16)


## Pill rectangle for a fixture whose screen bounds are `bounds`: horizontally centred on the bounds, vertically centred
## on its top edge, nudged a little above it. The width holds the padding, the icon (when `with_icon`) and the text.
static func board_rect(bounds: Rect2, text_width: float, zoom: float, with_icon: bool = true) -> Rect2:
	var size := text_size(zoom)
	var h := size * 1.5 + 4.0 * zoom
	var w := text_width + PAD_PX * 2.0 * zoom
	if with_icon:
		w += icon_size(h) + GAP_PX * zoom
	var centre := Vector2(bounds.get_center().x, bounds.position.y - LIFT_PX * zoom)
	return Rect2(centre.x - w * 0.5, centre.y - h * 0.5, w, h)


## Side of the square icon for a pill of height h.
static func icon_size(h: float) -> float:
	return h * ICON_RATIO


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
		if cmd["icon"] != null:
			draw_texture_rect(cmd["icon"], cmd["icon_rect"], false, TEXT_COLOR)
		draw_string(_font(), cmd["pos"], cmd["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, cmd["size"], TEXT_COLOR)


func _font() -> Font:
	var theme_font: Font = ThemeDB.get_default_theme().default_font
	return theme_font if theme_font != null else ThemeDB.fallback_font


func _rebuild_if_stale() -> void:
	var proj: IsoProjection = _world.projection
	var key := [_world.revision, proj.zoom, proj.origin, _world.fixtures.size(), _world.closed_registers]
	if key == _key:
		return
	_key = key
	_commands.clear()
	var font := _font()
	var size := text_size(proj.zoom)
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var closed: bool = _world.closed_registers.has(inst["instance_id"])
		var text := CLOSED_TEXT if closed else label_for(def)
		if text == "":
			continue
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var bounds := OverlayModel.fixture_bounds(proj, cells, float(def["dimensions_m"]["height"]))
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var icon_name := "" if closed else icon_for(def)
		var icon: Texture2D = UiIcons.texture(icon_name, 32) if icon_name != "" else null
		var rect := board_rect(bounds, text_width, proj.zoom, icon != null)
		var base: Color = CLOSED_COLOR if closed else _Presenter.CATEGORY_COLOR.get(def["allowed_categories"][0], _Presenter.REGISTER_COLOR)
		var box := StyleBoxFlat.new()
		box.bg_color = base.darkened(DARKEN)
		box.border_color = base.lightened(BORDER_LIGHTEN)
		box.set_border_width_all(1)
		box.set_corner_radius_all(roundi(rect.size.y * 0.5))   # a full pill
		var isize := icon_size(rect.size.y)
		var icon_rect := Rect2(rect.position.x + PAD_PX * proj.zoom, rect.get_center().y - isize * 0.5, isize, isize)
		var text_x := rect.position.x + PAD_PX * proj.zoom + (isize + GAP_PX * proj.zoom if icon != null else 0.0)
		var baseline := rect.position.y + (rect.size.y - font.get_height(size)) * 0.5 + font.get_ascent(size)
		_commands.append({
			"box": box, "rect": rect, "text": text, "pos": Vector2(text_x, baseline), "size": size,
			"icon": icon, "icon_rect": icon_rect,
		})
