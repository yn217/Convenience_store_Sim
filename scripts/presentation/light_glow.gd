class_name LightGlow
extends Node2D
## Issue #61 (light): warm additive glow pooled above each store fixture and a larger one at the
## entrance. Its strength follows the night-ness of LightingModel.tint(), so the store reads lit at
## night and nearly unlit at noon. Static (no animation, so reduce_motion has nothing to tone down),
## presentation only, drawn between the fixtures and the overlay layers, and it never takes input.

const DAY_FLOOR := 0.12   ## glow strength in full daylight
const NIGHT_PEAK := 0.6   ## glow strength at night
const FIXTURE_RADIUS_TILES := 1.1
const ENTRANCE_RADIUS_TILES := 3.0
const FIXTURE_LIFT_M := 0.4   ## glow source sits a little above the top of the fixture
const GLOW_COLOR := Color(1.0, 0.78, 0.45)
const TEXTURE_SIZE := 128

var _world: Node2D
var _texture: GradientTexture2D
var _intensity := DAY_FLOOR


func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_texture = _make_texture()


func _ready() -> void:
	_world = get_parent()


## Glow strength for a game clock value in seconds: DAY_FLOOR in daylight, rising to NIGHT_PEAK at night.
static func intensity(time_sec: int) -> float:
	var tint := LightingModel.tint(time_sec)
	var luma := 0.3 * tint.r + 0.59 * tint.g + 0.11 * tint.b
	# The ends come from LightingModel itself, so retuning the tint keeps night-ness in 0..1.
	var day_luma := _luma(LightingModel.DAY)
	var night_luma := _luma(LightingModel.NIGHT)
	var night := clampf((day_luma - luma) / maxf(day_luma - night_luma, 0.001), 0.0, 1.0)
	return lerpf(DAY_FLOOR, NIGHT_PEAK, night)


static func _luma(c: Color) -> float:
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b


## Called by StoreWorld when the clock changes.
func set_time(time_sec: int) -> void:
	var value := intensity(time_sec)
	if is_equal_approx(value, _intensity):
		return
	_intensity = value
	queue_redraw()


func _draw() -> void:
	if _world == null or _world.store_width <= 0 or _world.fixture_catalog == null:
		return
	var proj: IsoProjection = _world.projection
	var tile_px := proj.world_to_screen(1.0, 0.0).distance_to(proj.world_to_screen(0.0, 0.0))
	var color := Color(GLOW_COLOR, _intensity)
	for inst in _world.fixtures:
		var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
		if def.is_empty():
			continue
		var cells := StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"])
		var centre := Vector2.ZERO
		for c in cells:
			centre += Vector2(c)
		centre /= maxf(cells.size(), 1)
		var height := float(def["dimensions_m"]["height"]) + FIXTURE_LIFT_M
		_draw_glow(proj.world_to_screen(centre.x, centre.y, height), FIXTURE_RADIUS_TILES * tile_px, color)
	var entrance_color := Color(GLOW_COLOR, _intensity * 0.8)
	for t in _world.entrance_tiles:
		_draw_glow(proj.world_to_screen(0.0, float(t.y), 1.2), ENTRANCE_RADIUS_TILES * tile_px, entrance_color)


func _draw_glow(centre: Vector2, radius: float, color: Color) -> void:
	draw_texture_rect(_texture, Rect2(centre - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), false, color)


func _make_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = TEXTURE_SIZE
	tex.height = TEXTURE_SIZE
	return tex
