extends Node2D
## Placeholder fixture boxes (real sprites arrive with #9/#22/#26). Read-only: draws the
## snapshot's fixture list with the catalog dimensions, back-to-front by footprint position.
## The yellow edge marks the customer-facing access side, so rotation is visible.

const CATEGORY_COLOR := {
	"rice_ball": Color("e8a87c"), "oden": Color("c0794a"), "instant_noodle": Color("e6c35c"),
	"bread": Color("d9b38c"), "drink": Color("5caefd"), "snack": Color("e07a9a"),
	"dessert": Color("b79bdc"), "ice_cream": Color("8fd6e0"),
}
const REGISTER_COLOR := Color("7f8c99")
const FRONT_COLOR := Color("ffc873")
const INSET := 0.46

var _world: Node2D


func _ready() -> void:
	_world = get_parent().get_parent()


func _draw() -> void:
	if _world == null or _world.fixture_catalog == null:
		return
	var proj: IsoProjection = _world.projection
	var items: Array = []
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var lo := Vector2i(1 << 20, 1 << 20)
		var hi := Vector2i(-1, -1)
		for c in cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		items.append({"inst": inst, "def": def, "lo": lo, "hi": hi, "depth": hi.x + hi.y})
	items.sort_custom(func(a, b): return a["depth"] < b["depth"])
	for it in items:
		_draw_box(proj, it)


func _color_for(def: Dictionary) -> Color:
	if def["allowed_categories"].is_empty():
		return REGISTER_COLOR
	return CATEGORY_COLOR.get(def["allowed_categories"][0], REGISTER_COLOR)


func _draw_box(proj: IsoProjection, it: Dictionary) -> void:
	var lo: Vector2i = it["lo"]
	var hi: Vector2i = it["hi"]
	var h: float = float(it["def"]["dimensions_m"]["height"])
	var x0 := lo.x - INSET
	var y0 := lo.y - INSET
	var x1 := hi.x + INSET
	var y1 := hi.y + INSET
	var base := _color_for(it["def"])
	var a_g := proj.world_to_screen(x0, y0)
	var b_g := proj.world_to_screen(x1, y0)
	var c_g := proj.world_to_screen(x1, y1)
	var d_g := proj.world_to_screen(x0, y1)
	var a_t := proj.world_to_screen(x0, y0, h)
	var b_t := proj.world_to_screen(x1, y0, h)
	var c_t := proj.world_to_screen(x1, y1, h)
	var d_t := proj.world_to_screen(x0, y1, h)
	draw_colored_polygon(PackedVector2Array([b_g, c_g, c_t, b_t]), base.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([d_g, c_g, c_t, d_t]), base.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([a_t, b_t, c_t, d_t]), base)
	var edge := Color(0, 0, 0, 0.45)
	draw_polyline(PackedVector2Array([a_t, b_t, c_t, d_t, a_t]), edge, 1.5)
	draw_polyline(PackedVector2Array([d_t, d_g, c_g, c_t]), edge, 1.5)
	draw_line(c_g, b_g, edge, 1.5)
	var w := 4.0 * maxf(proj.zoom, 0.75)
	for e in it["def"]["access_edges"]:
		match PlacementRules.rotate_edge(e, it["inst"]["rotation"]):
			"N":
				draw_line(proj.world_to_screen(x0, y0, h), proj.world_to_screen(x1, y0, h), FRONT_COLOR, w)
			"E":
				draw_line(proj.world_to_screen(x1, y0, h), proj.world_to_screen(x1, y1, h), FRONT_COLOR, w)
			"S":
				draw_line(proj.world_to_screen(x0, y1, h), proj.world_to_screen(x1, y1, h), FRONT_COLOR, w)
			"W":
				draw_line(proj.world_to_screen(x0, y0, h), proj.world_to_screen(x0, y1, h), FRONT_COLOR, w)
