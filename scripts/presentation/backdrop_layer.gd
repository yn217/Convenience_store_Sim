class_name BackdropLayer
extends Node2D
## Street scene around the store: a dark-teal ground that fades to a vignette, a paving ring with joints,
## an apron with a door mat and an OPEN A-board on the entrance side, a kerb and road strip further out on that
## side, plus a combined generated landscape behind the store.
## The layer is drawn behind the store floor (show_behind_parent), uses the same IsoProjection as the floor, and
## never takes input. The geometry is pure (layout_items); sync() redraws only when the layout, camera or viewport
## changes, so nothing is recomputed per frame.

const SIDE_WEST := 0
const SIDE_NORTH := 1
const SIDE_EAST := 2
const SIDE_SOUTH := 3

const GROUND := Color("62795b")
const POOL := Color(0.30, 0.50, 0.46, 0.10)
const PAVE := Color("d6d0c3")
const PAVE_ALT := Color("e1d9ca")
const PAVE_JOINT := Color("aca599")
const APRON := Color("d6cbb4")
const MAT := Color("3b3733")
const MAT_EDGE := Color("5b544d")
const KERB := Color("d8d5cc")
const ROAD := Color("50565b")
const ROAD_LINE := Color("e9e2c8")
const SIGN_FRAME := Color("2b2b2b")
const SIGN_FACE := Color("f4efe2")
const SIGN_OPEN := Color("c8432f")
const SIGN_TEXT := Color("ffffff")
const SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const BUSH_DARK := Color("2f5d3e")
const BUSH_MID := Color("4b7d4f")
const BUSH_HI := Color("6f9e62")
const PLANTER := Color("7a5a43")
const VIGNETTE_EDGE := Color(0.0, 0.0, 0.0, 0.16)
const VIGNETTE_CLEAR := Color(0.0, 0.0, 0.0, 0.0)
const ExteriorBackdrop := preload("res://assets/generated/backgrounds/store_exterior_backdrop_v2/store_exterior_backdrop_v2.png")
const RearGrove := preload("res://assets/generated/backgrounds/rear_greenbelt_group_v1/rear_greenbelt_group_v1.png")
const OuterSidewalkStrip := preload("res://assets/generated/backgrounds/outer_sidewalk_strip_v1/outer_sidewalk_strip_v1.png")
## Ground-contact V apex in the generated PNG; foliage above it keeps its authored height.
const BACKDROP_GROUND_PX := Vector2(887.661, 435.866)
## Distance behind the far corner to the V bed's ground contact line, in world metres.
const BACKDROP_GROUND_OFFSET_M := 0.45
const BACKDROP_LEFT_END_PX := Vector2(0.0, 879.856)
const BACKDROP_RIGHT_END_PX := Vector2(1773.0, 878.561)
## Ground edge measured along the lower base of the grouped tree backdrop image.
const REAR_GROVE_GROUND_START_PX := Vector2(100.0, 610.0)
const REAR_GROVE_GROUND_END_PX := Vector2(2070.0, 610.0)
## Keep the tree height in world units across store sizes. 18m matches the prior 16x12 + 3m ends fit.
const REAR_GROVE_WORLD_LENGTH_M := 18.0
## Centerline measured through the long sidewalk strip; its full width and both curbs remain in the source art.
const OUTER_SIDEWALK_START_PX := Vector2(72.5, 130.0)
const OUTER_SIDEWALK_END_PX := Vector2(2050.0, 614.0)
const OUTER_SIDEWALK_EDGE_OVERHANG_M := 2.0
const RoadsideLandscape := preload("res://assets/generated/backgrounds/roadside_landscape_v1/roadside_landscape_v1.png")
const RoadsideKey := preload("res://assets/generated/backgrounds/roadside_landscape_v1/key.gdshader")
const SideLandscape := preload("res://assets/generated/backgrounds/roadside_greenery_v2/roadside_greenery_v2.png")
const SIDE_LANDSCAPE_SOURCE_SLOPE := 0.4999258304
const SIDE_LANDSCAPE_GROUND_START_PX := Vector2(15.0, 261.0)
const SIDE_LANDSCAPE_GROUND_END_PX := Vector2(1755.0, 1042.0)
const SIDE_LANDSCAPE_DEPTH_M := 0.55
const SIDE_LANDSCAPE_OVERHANG_M := 1.0
const AreaABackground := preload("res://assets/generated/backgrounds/area_a_roadside_v1/area_a_roadside_v1.png")
const AREA_A_FRONTAGE_P0 := Vector2(249.0, 29.0)
const AREA_A_FRONTAGE_P1 := Vector2(1657.0, 604.0)
const ROADSIDE_IMAGE_SCALE := 0.45
const ROADSIDE_START_PX := Vector2(123.0, 465.0)
const ROADSIDE_SPAN_M := 10.5

const PAVE_M := 2.0       ## paving ring width around the store footprint (tiles)
const KERB_M := 0.18
const PARK_DEPTH_M := 5.0  ## 3.8 m compact car plus wheel-stop and manoeuvring clearance
const ROAD_M := 3.0
const OUTER_SIDEWALK_M := 1.5
const FAR_M := 14.0       ## minimum road extension along the edge, past the store
const SLAB_INSET := 0.04

var _key: Array = []
var _ops: Array = []
var _mesh: ArrayMesh          # road/paving faces batched after the static landscape panel
var _ground_mesh: ArrayMesh    # viewport fill and soft pool, drawn before the combined scenery panel
var _scenery_break_index := -1
var _texts: Array = []        # text ops, drawn after the mesh
var _environment_transform := Transform2D()
var _environment_visible := false
var _roadside_grove_transform := Transform2D()
var _roadside_grove_visible := false
var _outer_sidewalk_transform := Transform2D()
var _outer_sidewalk_visible := false
var _roadside_sprite: Sprite2D
var _side_landscape_sprite: Sprite2D
var _area_a_sprite: Sprite2D


## Recomputes the backdrop when the layout, camera or viewport changed; otherwise does nothing.
## `dressed` (issue #110): the StoreDecor exterior layer draws the A-board and planters, so their fallbacks are omitted.
func sync(width: int, height: int, entrances: Array, proj: IsoProjection, viewport: Vector2, dressed: bool = false) -> void:
	var key := [width, height, entrances.duplicate(), proj.origin, proj.zoom, viewport, dressed]
	if key == _key:
		return
	_key = key
	_ops = layout_items(proj, width, height, entrances, viewport, dressed)
	_sync_environment(proj, width, height)
	_sync_roadside_grove(proj, width, height, entrances)
	_sync_outer_sidewalk(proj, width, height, entrances)
	_sync_area_a(proj, width, height, entrances)
	_sync_roadside(proj, width, height, entrances)
	_sync_side_landscape(proj, width, height, entrances)
	_build_mesh()
	queue_redraw()


## The flowerbed ends before the crossing even when the entrance is moved.
func _sync_roadside(proj: IsoProjection, width: int, height: int, entrances: Array) -> void:
	if _roadside_sprite == null:
		_roadside_sprite = Sprite2D.new()
		_roadside_sprite.centered = false
		_roadside_sprite.texture = RoadsideLandscape
		var mat := ShaderMaterial.new()
		mat.shader = RoadsideKey
		_roadside_sprite.material = mat
		add_child(_roadside_sprite)
	_roadside_sprite.visible = width > 0 and height > 0
	if not _roadside_sprite.visible:
		return
	var side := entrance_side(width, height, entrances)
	var span := entrance_span(side, width, height, entrances)
	var along := span.x - ROADSIDE_SPAN_M
	var depth := PAVE_M + PARK_DEPTH_M + KERB_M + ROAD_M + 0.32
	var point := side_point(side, depth, along, width, height)
	var scale := ROADSIDE_IMAGE_SCALE * proj.zoom
	var direction := -1.0 if side == SIDE_WEST or side == SIDE_EAST else 1.0
	_roadside_sprite.scale = Vector2(direction * scale, scale)
	_roadside_sprite.position = proj.world_to_screen(point.x, point.y) - Vector2(direction * ROADSIDE_START_PX.x, ROADSIDE_START_PX.y) * scale


## Uniformly place the V art by its ground-contact point, with independent checks for both world edges.
func _sync_environment(proj: IsoProjection, width: int, height: int) -> void:
	_environment_visible = width > 0 and height > 0
	if not _environment_visible:
		return
	_environment_transform = environment_transform(proj, width, height, Vector2(ExteriorBackdrop.get_size()))


## The grouped tree bed sits beyond the public road; roadway paint hides its roots at the ground contact.
func _sync_roadside_grove(proj: IsoProjection, width: int, height: int, entrances: Array) -> void:
	_roadside_grove_visible = width > 0 and height > 0
	if not _roadside_grove_visible:
		return
	_roadside_grove_transform = roadside_grove_transform(proj, width, height, entrance_side(width, height, entrances))


func _sync_outer_sidewalk(proj: IsoProjection, width: int, height: int, entrances: Array) -> void:
	_outer_sidewalk_visible = width > 0 and height > 0
	if not _outer_sidewalk_visible:
		return
	_outer_sidewalk_transform = outer_sidewalk_transform(proj, width, height, entrance_side(width, height, entrances), Vector2(OuterSidewalkStrip.get_size()))


## The unified parking apron is anchored by its measured frontage edge, not by the image canvas bounds.
func _sync_area_a(proj: IsoProjection, width: int, height: int, entrances: Array) -> void:
	if _area_a_sprite == null:
		_area_a_sprite = Sprite2D.new()
		_area_a_sprite.centered = false
		_area_a_sprite.texture = AreaABackground
		add_child(_area_a_sprite)
	_area_a_sprite.visible = width >= 8 and height >= 8
	if _area_a_sprite.visible:
		_area_a_sprite.transform = area_a_transform(proj, width, height, entrance_side(width, height, entrances))


## A fixed, combined sidewalk/planting strip follows a visible store edge. The small source-slope correction is
## applied as a vertical affine shear so tree and lamp posts stay vertical.
func _sync_side_landscape(proj: IsoProjection, width: int, height: int, entrances: Array) -> void:
	if _side_landscape_sprite == null:
		_side_landscape_sprite = Sprite2D.new()
		_side_landscape_sprite.centered = false
		_side_landscape_sprite.texture = SideLandscape
		add_child(_side_landscape_sprite)
	_side_landscape_sprite.visible = width >= 8 and height >= 8
	if not _side_landscape_sprite.visible:
		return
	var entrance := entrance_side(width, height, entrances)
	var landscape := landscape_side(entrance)
	# Cover the full exterior edge and extend past its endpoint so the return never reveals a gap.
	var edge_len := side_landscape_edge_length(landscape, width, height)
	var source_run_px := SIDE_LANDSCAPE_GROUND_END_PX.x - SIDE_LANDSCAPE_GROUND_START_PX.x
	var scale := edge_len * IsoProjection.HALF_TILE_W * proj.zoom / source_run_px
	# Match the side's visible isometric branch: east uses the +0.5 screen slope, south the -0.5 slope.
	var direction := 1.0 if landscape == SIDE_EAST else -1.0
	var shear := 0.5 - SIDE_LANDSCAPE_SOURCE_SLOPE
	var basis_x := Vector2(direction * scale, shear * scale)
	var basis_y := Vector2(0.0, scale)
	# Start at the far corner shared with the rear V; the measured garden edge spans the full side plus overhang.
	var edge_corner := landscape_corner(landscape, SIDE_LANDSCAPE_DEPTH_M, width, height)
	var point := proj.world_to_screen(edge_corner.x, edge_corner.y)
	var origin := point - basis_x * SIDE_LANDSCAPE_GROUND_START_PX.x - basis_y * SIDE_LANDSCAPE_GROUND_START_PX.y
	_side_landscape_sprite.transform = Transform2D(basis_x, basis_y, origin)


func _draw() -> void:
	if _ground_mesh != null:
		draw_mesh(_ground_mesh, null)
	# Paint the combined V art after the ground fill, then road/paving geometry, then far-wall occlusion.
	if _environment_visible:
		draw_set_transform_matrix(_environment_transform)
		draw_texture_rect(ExteriorBackdrop, Rect2(Vector2.ZERO, Vector2(ExteriorBackdrop.get_size())), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if _roadside_grove_visible:
		draw_set_transform_matrix(_roadside_grove_transform)
		draw_texture_rect(RearGrove, Rect2(Vector2.ZERO, Vector2(RearGrove.get_size())), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if _outer_sidewalk_visible:
		draw_set_transform_matrix(_outer_sidewalk_transform)
		draw_texture_rect(OuterSidewalkStrip, Rect2(Vector2.ZERO, Vector2(OuterSidewalkStrip.get_size())), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if _mesh != null:
		draw_mesh(_mesh, null)
	var owner_world := get_parent()
	if owner_world != null and owner_world.has_method("draw_background_wall_occlusion"):
		owner_world.call("draw_background_wall_occlusion", self)
	for op in _texts:
		draw_string(ThemeDB.fallback_font, op["pos"], op["text"], HORIZONTAL_ALIGNMENT_CENTER, op["width"], op["size"], op["color"])


## Ground root is fixed behind the far corner; each branch is measured against its own store edge.
static func environment_transform(proj: IsoProjection, width: int, height: int, texture_size: Vector2) -> Transform2D:
	if width <= 0 or height <= 0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Transform2D.IDENTITY
	var ground := environment_ground_anchor(proj)
	var left_end := proj.world_to_screen(-0.5 - BACKDROP_GROUND_OFFSET_M, height - 0.5 + BACKDROP_GROUND_OFFSET_M)
	var right_end := proj.world_to_screen(width - 0.5 + BACKDROP_GROUND_OFFSET_M, -0.5 - BACKDROP_GROUND_OFFSET_M)
	var left_scale := environment_branch_scale(ground, left_end, BACKDROP_GROUND_PX, BACKDROP_LEFT_END_PX)
	var right_scale := environment_branch_scale(ground, right_end, BACKDROP_GROUND_PX, BACKDROP_RIGHT_END_PX)
	# Each V branch is measured against its own wall endpoint. Fit the longer branch so both walls stay covered;
	# the shorter branch may extend behind the wall, preserving the artwork's proportions without a gap.
	var scale := maxf(left_scale, right_scale)
	var x_axis := Vector2(scale, 0.0)
	var y_axis := Vector2(0.0, scale)
	var origin := ground - x_axis * BACKDROP_GROUND_PX.x - y_axis * BACKDROP_GROUND_PX.y
	return Transform2D(x_axis, y_axis, origin)


static func environment_branch_scale(screen_ground: Vector2, screen_endpoint: Vector2, image_ground: Vector2, image_endpoint: Vector2) -> float:
	var image_run := (image_endpoint - image_ground).length()
	if image_run <= 0.0:
		return 0.0
	return (screen_endpoint - screen_ground).length() / image_run


static func environment_ground_anchor(proj: IsoProjection) -> Vector2:
	return proj.world_to_screen(-0.5 - BACKDROP_GROUND_OFFSET_M, -0.5 - BACKDROP_GROUND_OFFSET_M)


## Place a grouped tree row at a fixed world scale, centered on the selected store edge.
static func roadside_grove_transform(proj: IsoProjection, width: int, height: int, side: int) -> Transform2D:
	var edge_length := float(height if side == SIDE_WEST or side == SIDE_EAST else width)
	var depth := PAVE_M + PARK_DEPTH_M + KERB_M + ROAD_M + KERB_M + OUTER_SIDEWALK_M + 0.2
	var source_start := REAR_GROVE_GROUND_START_PX
	var source_end := REAR_GROVE_GROUND_END_PX
	var along_start := (edge_length - REAR_GROVE_WORLD_LENGTH_M) * 0.5
	var target_start := side_point(side, depth, along_start, width, height)
	var target_end := side_point(side, depth, along_start + REAR_GROVE_WORLD_LENGTH_M, width, height)
	# Reversing the longitudinal mapping on the y-oriented sides keeps the generated trees upright.
	if side == SIDE_WEST or side == SIDE_EAST:
		var swap := target_start
		target_start = target_end
		target_end = swap
	var screen_start := proj.world_to_screen(target_start.x, target_start.y)
	var screen_end := proj.world_to_screen(target_end.x, target_end.y)
	var source_run := source_end - source_start
	var target_run := screen_end - screen_start
	var scale := REAR_GROVE_WORLD_LENGTH_M * Vector2(IsoProjection.HALF_TILE_W, IsoProjection.HALF_TILE_H).length() * proj.zoom / source_run.length()
	var angle := target_run.angle() - source_run.angle()
	var basis_x := Vector2.RIGHT.rotated(angle) * scale
	var basis_y := Vector2.DOWN.rotated(angle) * scale
	return Transform2D(basis_x, basis_y, screen_start - basis_x * source_start.x - basis_y * source_start.y)


## Fit one generated sidewalk strip to the street-side world edge using its authored centerline endpoints.
static func outer_sidewalk_transform(proj: IsoProjection, width: int, height: int, side: int, texture_size: Vector2) -> Transform2D:
	if width <= 0 or height <= 0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Transform2D.IDENTITY
	var edge_length := float(height if side == SIDE_WEST or side == SIDE_EAST else width)
	var depth := PAVE_M + PARK_DEPTH_M + KERB_M + ROAD_M + KERB_M + OUTER_SIDEWALK_M * 0.5
	var target_start := side_point(side, depth, -OUTER_SIDEWALK_EDGE_OVERHANG_M, width, height)
	var target_end := side_point(side, depth, edge_length + OUTER_SIDEWALK_EDGE_OVERHANG_M, width, height)
	if side == SIDE_WEST or side == SIDE_EAST:
		var swap := target_start
		target_start = target_end
		target_end = swap
	var screen_start := proj.world_to_screen(target_start.x, target_start.y)
	var screen_end := proj.world_to_screen(target_end.x, target_end.y)
	var source_run := OUTER_SIDEWALK_END_PX - OUTER_SIDEWALK_START_PX
	var target_run := screen_end - screen_start
	var scale := target_run.length() / source_run.length()
	var angle := target_run.angle() - source_run.angle()
	var basis_x := Vector2.RIGHT.rotated(angle) * scale
	var basis_y := Vector2.DOWN.rotated(angle) * scale
	return Transform2D(basis_x, basis_y, screen_start - basis_x * OUTER_SIDEWALK_START_PX.x - basis_y * OUTER_SIDEWALK_START_PX.y)


static func side_landscape_edge_length(side: int, width: int, height: int) -> float:
	return float(height if side == SIDE_EAST or side == SIDE_WEST else width) + SIDE_LANDSCAPE_OVERHANG_M


## Match the source frontage to the entrance side while keeping the source image uniformly scaled.
static func area_a_transform(proj: IsoProjection, width: int, height: int, side: int) -> Transform2D:
	var edge := area_a_world_endpoints(width, height, side)
	var screen_start := proj.world_to_screen(edge[0].x, edge[0].y)
	var screen_end := proj.world_to_screen(edge[1].x, edge[1].y)
	var source_frontage := AREA_A_FRONTAGE_P1 - AREA_A_FRONTAGE_P0
	var target_frontage := screen_end - screen_start
	var scale := target_frontage.length() / source_frontage.length()
	var angle := target_frontage.angle() - source_frontage.angle()
	var basis_x := Vector2.RIGHT.rotated(angle) * scale
	var basis_y := Vector2.DOWN.rotated(angle) * scale
	return Transform2D(basis_x, basis_y, screen_start - basis_x * AREA_A_FRONTAGE_P0.x - basis_y * AREA_A_FRONTAGE_P0.y)


## World endpoints for the combined parking artwork's measured frontage edge, ordered P0 to P1.
static func area_a_world_endpoints(width: int, height: int, side: int) -> Array[Vector2]:
	match side:
		SIDE_WEST:
			return [Vector2(-0.5, height - 0.5), Vector2(-0.5, -0.5)]
		SIDE_NORTH:
			return [Vector2(width - 0.5, -0.5), Vector2(-0.5, -0.5)]
		SIDE_EAST:
			return [Vector2(width - 0.5, -0.5), Vector2(width - 0.5, height - 0.5)]
		_:
			return [Vector2(-0.5, height - 0.5), Vector2(width - 0.5, height - 0.5)]


## Fan-triangulates the (convex) pieces in paint order into one vertex-coloured mesh.
func _build_mesh() -> void:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	_scenery_break_index = -1
	_texts = []
	for op in _ops:
		if op["kind"] == &"text":
			_texts.append(op)
			continue
		if op["kind"] == &"scenery_break":
			_scenery_break_index = verts.size()
			continue
		var pts: PackedVector2Array = op["points"]
		for k in range(1, pts.size() - 1):
			for idx in [0, k, k + 1]:
				verts.append(pts[idx])
				cols.append(op["colors"][idx] if op["kind"] == &"gradient" else op["color"])
	_ground_mesh = null
	_mesh = null
	if verts.is_empty():
		return
	if _scenery_break_index < 0:
		_mesh = _make_mesh(verts, cols)
		return
	_ground_mesh = _make_mesh(verts.slice(0, _scenery_break_index), cols.slice(0, _scenery_break_index))
	_mesh = _make_mesh(verts.slice(_scenery_break_index), cols.slice(_scenery_break_index))


func _make_mesh(verts: PackedVector2Array, cols: PackedColorArray) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


## Every piece of the street, in paint order. The scenery_break entry marks where the backdrop is drawn.
## Other entries have kind &"poly", &"gradient", or &"text":
## polys carry "points" and "color", gradients carry "points" and per-vertex "colors", text carries "pos",
## "text", "size", "width" and "color". Points are screen coordinates. Empty for a store without a floor.
static func layout_items(proj: IsoProjection, width: int, height: int, entrances: Array, viewport: Vector2, dressed: bool = false) -> Array:
	var out: Array = []
	if width <= 0 or height <= 0:
		return out
	var side := entrance_side(width, height, entrances)
	var span := entrance_span(side, width, height, entrances)
	var along_margin := road_along_margin(proj, viewport)
	var edge_length := float(height if side == SIDE_WEST or side == SIDE_EAST else width)
	var along0 := -along_margin
	var along1 := edge_length + along_margin

	# Ground: flat fill of the viewport, a soft lighter pool around the store, then the vignette on top.
	out.append(_poly(PackedVector2Array([Vector2.ZERO, Vector2(viewport.x, 0.0), viewport, Vector2(0.0, viewport.y)]), GROUND))
	for grow in [9.0, 6.0, 3.0]:
		out.append(_poly(_world_pts(proj, _rect_world(width, height, grow)), POOL))
	# Insert the static scenery after background tone, then draw all road/paving geometry above it.
	out.append({"kind": &"scenery_break"})

	# Kerb and road on the entrance side, beyond the paving ring.
	var parking_end := PAVE_M + PARK_DEPTH_M
	var road_d0 := parking_end + KERB_M
	var forecourt_along1 := edge_length
	out.append(_poly(_side_quad(proj, side, width, height, parking_end, road_d0, along0, along1), KERB))
	out.append(_poly(_side_quad(proj, side, width, height, road_d0, road_d0 + ROAD_M, along0, along1), ROAD))
	# A continuous forecourt supports the existing bay sprites only across the store frontage, avoiding an asphalt wedge.
	out.append(_poly(_side_quad(proj, side, width, height, PAVE_M, parking_end, 0.0, forecourt_along1), Color("626367")))
	# A narrow outer curb and paved pedestrian strip close the road edge before the green ground begins.
	var outer_kerb_d0 := road_d0 + ROAD_M
	var outer_walk_d0 := outer_kerb_d0 + KERB_M
	out.append(_poly(_side_quad(proj, side, width, height, outer_kerb_d0, outer_walk_d0, along0, along1), KERB))
	# Fine deterministic aggregate: quiet at the normal view, without per-frame noise or texture seams.
	for d in range(6):
		for k in range(int(along0), int(along1)):
			var jitter := FloorStyle.hash01(k, d, 19)
			var depth := road_d0 + 0.2 + float(d) * 0.45
			out.append(_poly(_side_quad(proj, side, width, height, depth, depth + 0.035, float(k) + jitter, float(k) + jitter + 0.16), Color(0.85, 0.86, 0.87, 0.07)))
	var dash_mid := road_d0 + ROAD_M * 0.5
	var a := along0
	while a < along1:
		out.append(_poly(_side_quad(proj, side, width, height, dash_mid - 0.06, dash_mid + 0.06, a, a + 1.2), ROAD_LINE))
		a += 3.0

	# Crossing is aligned with the actual doorway, and spans only the public road.
	for stripe in range(6):
		var d := road_d0 + 0.2 + float(stripe) * 0.45
		out.append(_poly(_side_quad(proj, side, width, height, d, d + 0.24, span.x - 0.15, span.y + 0.15), ROAD_LINE))
	# Kerb joints and small drainage grates establish the pavement/forecourt boundary.
	for k in range(-2, int(along1), 2):
		out.append(_poly(_side_quad(proj, side, width, height, parking_end, road_d0, float(k), float(k) + 0.025), Color("a3a39c")))
		if k % 6 == 0:
			out.append(_poly(_side_quad(proj, side, width, height, parking_end - 0.24, parking_end - 0.06, float(k), float(k) + 0.48), Color("42494b")))
			for slit in range(5):
				var a0 := float(k) + 0.04 + float(slit) * 0.09
				out.append(_poly(_side_quad(proj, side, width, height, parking_end - 0.22, parking_end - 0.08, a0, a0 + 0.025), Color("8d9694")))

	# Paving ring: joint colour underneath, then one inset slab per tile outside the store footprint.
	out.append(_poly(_world_pts(proj, _rect_world(width, height, PAVE_M)), PAVE_JOINT))
	for j in range(-int(PAVE_M), height + int(PAVE_M)):
		for i in range(-int(PAVE_M), width + int(PAVE_M)):
			if i >= 0 and i < width and j >= 0 and j < height:
				continue
			var slab := Rect2(i - 0.5 + SLAB_INSET, j - 0.5 + SLAB_INSET, 1.0 - SLAB_INSET * 2.0, 1.0 - SLAB_INSET * 2.0)
			var col := PAVE if FloorStyle.hash01(i, j, 7) < 0.5 else PAVE_ALT
			out.append(_poly(_world_pts(proj, slab), col))
			# Subdivide each metre slab into smaller, readable pavers while retaining the original ring geometry.
			var joint := Rect2(float(i) - 0.48, float(j) - 0.015, 0.96, 0.03)
			out.append(_poly(_world_pts(proj, joint), Color("c1b9ab")))
			joint = Rect2(float(i) - 0.015, float(j) - 0.48, 0.03, 0.96)
			out.append(_poly(_world_pts(proj, joint), Color("c1b9ab")))

	# Apron along the entrance, door mats in front of each entrance tile, and the A-board sign.
	out.append(_poly(_side_quad(proj, side, width, height, 0.0, PAVE_M, span.x - 1.0, span.y + 1.0), APRON))
	for e in entrances:
		var t: Vector2i = e
		var along := float(_along_coord(side, t))
		if not _on_side(side, t, width, height):
			continue
		out.append(_poly(_side_quad(proj, side, width, height, 0.15, 0.95, along - 0.38, along + 0.38), MAT_EDGE))
		out.append(_poly(_side_quad(proj, side, width, height, 0.22, 0.88, along - 0.30, along + 0.30), MAT))
	# The apron itself sits behind the entrance-side wall, so the A-board stands on the visible pavement at the
	# front corner of that side (the end of the edge that is closest to the viewer).
	var front := float(height - 1) + 0.7 if side == SIDE_WEST or side == SIDE_EAST else float(width - 1) + 0.7
	if not dressed:
		out.append_array(_a_board(proj, side_point(side, 1.2, front, width, height)))

		# Fallback planters at the outer corners.
		var s := proj.zoom
		var y0 := -0.5
		var x1 := width - 0.5
		var y1 := height - 0.5
		for corner in [Vector2(x1 + 1.0, y1 + 1.0), Vector2(x1 + 1.0, y0 - 1.0)]:
			out.append_array(_planter(proj.world_to_screen(corner.x, corner.y), s))

	out.append_array(_vignette(viewport))
	return out


## Extend the street beyond the viewport even at low zoom and the allowed camera pan limit.
static func road_along_margin(proj: IsoProjection, viewport: Vector2) -> float:
	var projected_tile_run := Vector2(IsoProjection.HALF_TILE_W, IsoProjection.HALF_TILE_H).length() * proj.zoom
	if projected_tile_run <= 0.0:
		return FAR_M
	var pan_clearance := IsoProjection.PAN_MARGIN_TILES * 2.0 * projected_tile_run
	var required_px := viewport.length() * 0.5 + 128.0 * proj.zoom + pan_clearance
	return maxf(FAR_M, ceilf(required_px / projected_tile_run))


## Side of the store the entrance is on: west (x = 0) by default, else north, east or south.
static func entrance_side(width: int, height: int, entrances: Array) -> int:
	var sides := [SIDE_WEST, SIDE_NORTH, SIDE_EAST, SIDE_SOUTH]
	for side in sides:
		for e in entrances:
			if _on_side(side, e, width, height):
				return side
	return SIDE_WEST


## Along-edge range (tile coordinates) covered by the entrance tiles on that side, padded by half a tile.
static func entrance_span(side: int, width: int, height: int, entrances: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for e in entrances:
		var t: Vector2i = e
		if _on_side(side, t, width, height):
			var c := float(_along_coord(side, t))
			lo = minf(lo, c)
			hi = maxf(hi, c)
	if lo == INF:
		var mid := float(height) * 0.5 if side == SIDE_WEST or side == SIDE_EAST else float(width) * 0.5
		return Vector2(mid - 0.5, mid + 0.5)
	return Vector2(lo - 0.5, hi + 0.5)


## The combined planted sidewalk sits on the visible side adjacent to the entrance, away from its road crossing.
static func landscape_side(entrance: int) -> int:
	return SIDE_SOUTH if entrance == SIDE_EAST else SIDE_EAST


## The combined U-shaped sidewalk panel starts at the store's far corner, matching the V-shaped rear backdrop.
static func landscape_corner(side: int, depth: float, width: int, height: int) -> Vector2:
	if side == SIDE_EAST:
		return Vector2(float(width) - 0.5 + depth, -0.5)
	return Vector2(-0.5, float(height) - 0.5 + depth)


## World point at `depth` metres out from the store edge on `side`, at tile coordinate `along` on that edge.
static func side_point(side: int, depth: float, along: float, width: int, height: int) -> Vector2:
	var x0 := -0.5
	var y0 := -0.5
	var x1 := width - 0.5
	var y1 := height - 0.5
	match side:
		SIDE_WEST:
			return Vector2(x0 - depth, along)
		SIDE_NORTH:
			return Vector2(along, y0 - depth)
		SIDE_EAST:
			return Vector2(x1 + depth, along)
	return Vector2(along, y1 + depth)


static func _on_side(side: int, t: Vector2i, width: int, height: int) -> bool:
	match side:
		SIDE_WEST:
			return t.x == 0
		SIDE_NORTH:
			return t.y == 0
		SIDE_EAST:
			return t.x == width - 1
	return t.y == height - 1


static func _along_coord(side: int, t: Vector2i) -> int:
	return t.y if side == SIDE_WEST or side == SIDE_EAST else t.x


## The outer edge of an entrance tile as two ground points (tile-unit world coordinates), on the wall it sits on.
## Used for the door line and anything that must sit at the threshold, whatever side the entrance is on.
static func door_segment(t: Vector2i, width: int, height: int) -> Array:
	var side := entrance_side(width, height, [t])
	var a := float(_along_coord(side, t))
	match side:
		SIDE_WEST:
			return [Vector2(-0.5, a - 0.5), Vector2(-0.5, a + 0.5)]
		SIDE_NORTH:
			return [Vector2(a - 0.5, -0.5), Vector2(a + 0.5, -0.5)]
		SIDE_EAST:
			return [Vector2(width - 0.5, a - 0.5), Vector2(width - 0.5, a + 0.5)]
	return [Vector2(a - 0.5, height - 0.5), Vector2(a + 0.5, height - 0.5)]


## Quad on the ground plane between two depths and two along-edge positions, projected to screen points.
static func _side_quad(proj: IsoProjection, side: int, width: int, height: int, d0: float, d1: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array([
		side_point(side, d0, a0, width, height), side_point(side, d1, a0, width, height),
		side_point(side, d1, a1, width, height), side_point(side, d0, a1, width, height),
	])
	return _world_pts(proj, pts)


## Floor-plane rectangle around the store footprint, grown by `grow` tiles on every side.
static func _rect_world(width: int, height: int, grow: float) -> Rect2:
	return Rect2(-0.5 - grow, -0.5 - grow, width + grow * 2.0, height + grow * 2.0)


static func _world_pts(proj: IsoProjection, r) -> PackedVector2Array:
	if r is Rect2:
		var rc: Rect2 = r
		r = PackedVector2Array([
			Vector2(rc.position.x, rc.position.y), Vector2(rc.end.x, rc.position.y),
			Vector2(rc.end.x, rc.end.y), Vector2(rc.position.x, rc.end.y),
		])
	var out := PackedVector2Array()
	for p in r:
		out.append(proj.world_to_screen(p.x, p.y))
	return out


static func _poly(points: PackedVector2Array, color: Color) -> Dictionary:
	return {"kind": &"poly", "points": points, "color": color}


static func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> Dictionary:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return _poly(pts, color)


## Screen-space vignette: transparent inside an inset rectangle, darkening towards the viewport edges.
static func _vignette(viewport: Vector2) -> Array:
	var vw := viewport.x
	var vh := viewport.y
	var ix0 := vw * 0.16
	var ix1 := vw * 0.84
	var iy0 := vh * 0.18
	var iy1 := vh * 0.82
	var e := VIGNETTE_EDGE
	var c := VIGNETTE_CLEAR
	return [
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(ix1, iy0), Vector2(ix0, iy0)]), "colors": PackedColorArray([e, e, c, c])},
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(vw, 0), Vector2(vw, vh), Vector2(ix1, iy1), Vector2(ix1, iy0)]), "colors": PackedColorArray([e, e, c, c])},
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(vw, vh), Vector2(0, vh), Vector2(ix0, iy1), Vector2(ix1, iy1)]), "colors": PackedColorArray([e, e, c, c])},
		{"kind": &"gradient", "points": PackedVector2Array([Vector2(0, vh), Vector2(0, 0), Vector2(ix0, iy0), Vector2(ix0, iy1)]), "colors": PackedColorArray([e, e, c, c])},
	]


## Standing A-board: dark frame, cream face, red OPEN band with white lettering. `g` is its ground point.
static func _a_board(proj: IsoProjection, ground: Vector2) -> Array:
	var g := proj.world_to_screen(ground.x, ground.y)
	var s := proj.zoom
	var w := 14.0 * s
	var top := 34.0 * s
	var out: Array = []
	out.append(_ellipse(g + Vector2(3.0 * s, 1.0 * s), 18.0 * s, 5.0 * s, SHADOW))
	out.append(_poly(PackedVector2Array([g + Vector2(-w - 2.0 * s, 0), g + Vector2(w + 2.0 * s, 0), g + Vector2(w + 2.0 * s, -top), g + Vector2(-w - 2.0 * s, -top)]), SIGN_FRAME))
	out.append(_poly(PackedVector2Array([g + Vector2(-w, -2.0 * s), g + Vector2(w, -2.0 * s), g + Vector2(w, -top + 2.0 * s), g + Vector2(-w, -top + 2.0 * s)]), SIGN_FACE))
	out.append(_poly(PackedVector2Array([g + Vector2(-w, -top + 2.0 * s), g + Vector2(w, -top + 2.0 * s), g + Vector2(w, -top * 0.62), g + Vector2(-w, -top * 0.62)]), SIGN_OPEN))
	out.append({"kind": &"text", "pos": g + Vector2(0, -top * 0.62 - 2.0 * s), "text": "OPEN", "size": maxi(8, roundi(8.0 * s)), "width": w * 2.0, "color": SIGN_TEXT})
	return out


## Planter box with a rounded shrub on top. `g` is the ground point, `s` the zoom.
static func _planter(g: Vector2, s: float) -> Array:
	var out: Array = []
	out.append(_ellipse(g + Vector2(0, 2.0 * s), 26.0 * s, 7.0 * s, SHADOW))
	out.append(_poly(PackedVector2Array([g + Vector2(-18.0 * s, -12.0 * s), g + Vector2(18.0 * s, -12.0 * s), g + Vector2(18.0 * s, 0), g + Vector2(-18.0 * s, 0)]), PLANTER))
	out.append(_ellipse(g + Vector2(0, -22.0 * s), 26.0 * s, 18.0 * s, BUSH_DARK))
	out.append(_ellipse(g + Vector2(-5.0 * s, -28.0 * s), 17.0 * s, 12.0 * s, BUSH_MID))
	out.append(_ellipse(g + Vector2(-10.0 * s, -33.0 * s), 8.0 * s, 5.0 * s, BUSH_HI))
	return out
