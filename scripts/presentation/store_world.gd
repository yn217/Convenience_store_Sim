extends Node2D
## Read-only presenter of the store (01 §2): floor, perimeter edge walls, west entrance,
## fixtures, camera (zoom/pan through IsoProjection) and tile hover/selection/ghost overlays.
## It never changes game state: clicks become signals that BuildController turns into commands.

signal selection_changed(tile: Vector2i)
signal hover_changed(tile: Vector2i)
signal tile_clicked(tile: Vector2i)
signal cancel_requested
signal rotate_requested
signal delete_requested
signal undo_requested
signal redo_requested
signal pause_toggle_requested
signal overlay_changed(mode: int)
signal customer_selected(customer_id: String)
signal pick_candidates_changed(labels: Array)

enum Mode { OBSERVE, PLACE, MOVE }

const NO_TILE := Vector2i(-1, -1)
const WALL := Color(0.25, 0.25, 0.28)
const DOOR := Color(0.25, 0.60, 0.85)
const OUTSIDE := Color(0.55, 0.62, 0.50)
## Which refit fit_view() does: the default interior fit (floor fills the safe area) or the whole store (F / Shift+F).
enum FitMode { INTERIOR, WHOLE }

var store_width: int = 0
var store_height: int = 0
var revision: int = -1
var entrance_tiles: Array[Vector2i] = []
var _floor_key: Array = []   # what the floor and walls were last drawn from (layout, camera, viewport)
var _shadows: Array = []     # fixture contact shadows in world space, cached by _shadow_sig (layout signature)
var _shadow_sig: Array = []
var _time_sec := -1          # game clock of the last snapshot (presentation light only), -1 before the first one
var _debug_paths: DebugPathLayer   # customer path overlay (F3); draws nothing while disabled
var fixtures: Array = []
var fixture_catalog: FixtureCatalog
var shelf_stock: Dictionary = {}
var shelf_skus: Dictionary = {}          # {fixture_id: {slot_id: sku_id}} from the snapshot
var product_catalog: ProductCatalog      # SKU lookup for the package icons (set by the app)
var customers: Array = []
var checkout_duration_sec: int = 0       # game seconds per checkout (balance), for the queue estimate
var speed_setting: int = 0
var walk_tiles_per_game_second: float = 0.0   # the simulation's walking speed: figures keep to it (#117 v2)
var fixture_sales: Dictionary = {}
var closed_registers: Array = []         # register ids with nobody at the till (#113): SignLayer shows 休止中
var overlay_mode: int = OverlayModel.Mode.NORMAL
var selected_customer: String = ""
## Click cycling over overlapping objects: where the last pick was and which candidate it chose.
var _pick_pos := Vector2(-1e9, -1e9)
var _pick_index := 0
var projection := IsoProjection.new()
var hover_tile := NO_TILE
var selected_tile := NO_TILE
var mode: Mode = Mode.OBSERVE
## True once the player zoomed/panned; resizing then keeps their view instead of refitting.
var user_moved := false
var fit_mode: FitMode = FitMode.INTERIOR
## Screen px the UI covers around the viewport (x = left rail, y = top HUD, z = right, w = bottom summary).
## fit_view() centres the floor in what is left. Set by MainLayout; zero means the whole viewport.
var safe_inset := Vector4.ZERO

@onready var _selection: Node2D = $SelectionOverlay
@onready var _fixture_view: Node2D = $ObjectSortRoot/FixturePresenter
@onready var _light_glow: LightGlow = get_node_or_null("LightGlow") as LightGlow
@onready var _light_spill: LightSpill = get_node_or_null("LightSpill") as LightSpill   # #114 storefront spill, lamps
@onready var _sign_layer: SignLayer = get_node_or_null("SignLayer") as SignLayer
@onready var _walls: WallLayer = get_node_or_null("WallLayer") as WallLayer
@onready var _backdrop: BackdropLayer = get_node_or_null("BackdropLayer") as BackdropLayer
@onready var _ext_decor: StoreDecor = get_node_or_null("ExteriorDecor") as StoreDecor   # #110 static dressing
@onready var _wall_decor: StoreDecor = get_node_or_null("WallDecor") as StoreDecor
@onready var _front_decor: StoreDecor = get_node_or_null("FrontDecor") as StoreDecor
@onready var _facade_canopy: StoreDecor = get_node_or_null("FacadeCanopy") as StoreDecor
@onready var _reg_floor: StoreDecor = get_node_or_null("RegisterFloorDecor") as StoreDecor   # #113 checkout area
@onready var _reg_top: StoreDecor = get_node_or_null("RegisterTopDecor") as StoreDecor


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_debug_paths = DebugPathLayer.new()
	_debug_paths.name = "DebugPathLayer"
	add_child(_debug_paths)   # last child: drawn over the fixtures and customers, off until F3
	_debug_paths.attach(self, _fixture_view)


## Customer path overlay on/off (F3 or --debug-paths). Off in normal play: nothing is drawn or computed.
func set_debug_paths(on: bool) -> void:
	_debug_paths.enabled = on
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		set_debug_paths(not _debug_paths.enabled)
		get_viewport().set_input_as_handled()


func apply_snapshot(snapshot: Dictionary) -> void:
	var first := store_width <= 0
	var layout := FloorStyle.layout_signature(snapshot.get("fixtures", []))
	var floor_key := [int(snapshot["store_width"]), int(snapshot["store_height"]), snapshot.get("entrance_tiles", []), layout, projection.origin, projection.zoom, viewport_size()]
	var floor_changed := floor_key != _floor_key
	_floor_key = floor_key
	store_width = int(snapshot["store_width"])
	store_height = int(snapshot["store_height"])
	revision = int(snapshot["revision"])
	entrance_tiles.clear()
	for t in snapshot.get("entrance_tiles", []):
		entrance_tiles.append(t)
	fixtures = snapshot.get("fixtures", [])
	if layout != _shadow_sig and fixture_catalog != null:
		_shadow_sig = layout
		_shadows = FloorStyle.fixture_shadows(fixtures, fixture_catalog)
	shelf_stock = snapshot.get("shelf_stock", {})
	shelf_skus = snapshot.get("shelf_skus", {})
	customers = snapshot.get("customers", [])
	if int(snapshot.get("passersby_per_day", 0)) > 0 and snapshot.has("time_sec"):   # #142: people walking past (presentation only)
		customers = customers + Passersby.views(int(snapshot["time_sec"]), int(snapshot["store_width"]), int(snapshot["store_height"]),
			snapshot.get("entrance_tiles", []), float(snapshot.get("walk_tiles_per_game_second", 0.0)), int(snapshot["passersby_per_day"]))
	checkout_duration_sec = int(snapshot.get("checkout_duration_sec", 0))
	speed_setting = int(snapshot.get("speed_setting", 0))
	walk_tiles_per_game_second = float(snapshot.get("walk_tiles_per_game_second", 0.0))
	fixture_sales = snapshot.get("fixture_sales", {})
	closed_registers = snapshot.get("closed_registers", [])
	if snapshot.has("time_sec"):
		_time_sec = int(snapshot["time_sec"])
		_apply_time_tint()
		if _light_glow != null:
			_light_glow.set_time(_time_sec)
		_sync_light_spill()
	if selected_customer != "" and not customers.any(func(c): return c["customer_id"] == selected_customer):
		selected_customer = ""
		customer_selected.emit("")
	if first or not in_store(selected_tile):
		_set_selected(NO_TILE)
	if first:
		fit_view()
	elif floor_changed:
		_refresh()
	else:
		# Views are republished about 20 times a second. The floor and walls only depend on the layout, the
		# camera and the viewport (floor_key), so a publish that changes none of them does not redraw the floor.
		_refresh_objects()


func tile_count() -> int:
	return store_width * store_height


func in_store(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < store_width and c.y < store_height


func viewport_size() -> Vector2:
	return get_viewport_rect().size


## Refits the camera in the current fit mode (game start, resize, after a load). Forgets manual zoom/pan.
func fit_view() -> void:
	if fit_mode == FitMode.WHOLE:
		fit_whole()
	else:
		fit_interior()


## Default view after a fresh start or a loaded save: interior fit, whatever mode the player had.
func reset_default_view() -> void:
	fit_mode = FitMode.INTERIOR
	fit_view()


## F key: whole floor (walls and exterior included) visible and centred, forgetting manual zoom/pan.
func fit_whole() -> void:
	fit_mode = FitMode.WHOLE
	if store_width <= 0:
		return
	user_moved = false
	# The store fits the part of the viewport that the UI does not cover (safe_inset), so a refit never hides it
	# under the HUD, rail or summary. Panels that open later overlay the store and do not move the camera.
	var area := _safe_area()
	projection.fit_floor(area.size, store_width, store_height)
	projection.origin += area.position
	_refresh()


## Shift+F: switches between the interior fit and the whole fit.
func toggle_fit_mode() -> void:
	fit_mode = FitMode.INTERIOR if fit_mode == FitMode.WHOLE else FitMode.WHOLE
	fit_view()


## Interior fit: the floor fills most of the safe area, centred 1.5 tiles toward the entrances (see IsoProjection).
func fit_interior() -> void:
	fit_mode = FitMode.INTERIOR
	if store_width <= 0:
		return
	user_moved = false
	projection.fit_interior(_safe_area(), store_width, store_height,
		IsoProjection.entrance_shift(entrance_tiles, store_width, store_height))
	_refresh()


## The part of the viewport the UI leaves free (safe_inset), as a screen rect.
func _safe_area() -> Rect2:
	var inset := safe_inset
	return Rect2(Vector2(inset.x, inset.y), viewport_size() - Vector2(inset.x + inset.z, inset.y + inset.w))


func zoom_at(pivot: Vector2, new_zoom: float) -> void:
	user_moved = true
	projection.zoom_at(pivot, new_zoom)
	projection.clamp_to_store_area(viewport_size(), store_width, store_height)
	_refresh()


func pan_by(delta: Vector2) -> void:
	user_moved = true
	projection.pan(delta)
	projection.clamp_to_store_area(viewport_size(), store_width, store_height)
	_refresh()


## Highlights the store tile under `screen_pos` (viewport coordinates).
## Returns the hovered tile, or NO_TILE when the point is outside the floor.
func set_hover_screen(screen_pos: Vector2) -> Vector2i:
	var c := projection.screen_to_tile(screen_pos)
	var tile := c if in_store(c) else NO_TILE
	var changed := tile != hover_tile
	hover_tile = tile
	_update_canopy_visibility()
	if _selection != null:
		if hover_tile == NO_TILE:
			_selection.clear()
		else:
			_selection.show_tile(projection.tile_diamond(hover_tile))
	if changed:
		hover_changed.emit(hover_tile)
	return hover_tile


## Left click: in OBSERVE it selects the tile (outside the floor deselects); in a build
## mode it only reports the tile, and the controller decides what to commit.
func primary_click(screen_pos: Vector2) -> void:
	var c := projection.screen_to_tile(screen_pos)
	var tile := c if in_store(c) else NO_TILE
	if mode == Mode.OBSERVE:
		_pick(screen_pos, tile)
	elif tile != NO_TILE:
		tile_clicked.emit(tile)


## Everything under a screen point, frontmost first: customers, fixtures (by their visible outline,
## so a tall case also catches clicks on the floor it hides), then the floor tile itself.
## -> Array of {"kind": "customer"|"fixture"|"tile", "id": String, "tile": Vector2i, "label": String}
func pick_candidates(screen_pos: Vector2) -> Array:
	var out: Array = []
	var seen := {}
	if _fixture_view != null and fixture_catalog != null:
		var ordered: Array = _fixture_view.compose()
		ordered.reverse()
		for it in ordered:
			if it["kind"] == "customer":
				if OverlayModel.customer_rect(projection, it["pos"]).has_point(screen_pos):
					out.append({"kind": "customer", "id": it["customer"]["customer_id"], "tile": it["customer"]["tile"], "label": "客 " + it["customer"]["customer_id"]})
				continue
			var inst: Dictionary = it["inst"]
			if seen.has(inst["instance_id"]):
				continue
			var cells := StoreGrid.footprint_cells(it["def"]["footprint"], inst["x"], inst["y"], inst["rotation"])
			var poly := OverlayModel.hit_polygon(projection, cells, float(it["def"]["dimensions_m"]["height"]))
			if Geometry2D.is_point_in_polygon(screen_pos, poly):
				seen[inst["instance_id"]] = true
				out.append({"kind": "fixture", "id": inst["instance_id"], "tile": Vector2i(inst["x"], inst["y"]), "label": it["def"]["display_name"]})
	var floor_tile := projection.screen_to_tile(screen_pos)
	if in_store(floor_tile):
		out.append({"kind": "tile", "id": "", "tile": floor_tile, "label": "床 (%d, %d)" % [floor_tile.x, floor_tile.y]})
	return out


## Select the frontmost candidate; clicking again on the same spot moves on to the next one behind it.
func _pick(screen_pos: Vector2, fallback_tile: Vector2i) -> void:
	var cands := pick_candidates(screen_pos)
	if cands.is_empty():
		_pick_pos = Vector2(-1e9, -1e9)
		_set_customer("")
		_set_selected(fallback_tile)
		pick_candidates_changed.emit([])
		return
	if screen_pos.distance_to(_pick_pos) <= 6.0:
		_pick_index = (_pick_index + 1) % cands.size()
	else:
		_pick_index = 0
	_pick_pos = screen_pos
	var chosen: Dictionary = cands[_pick_index]
	if chosen["kind"] == "customer":
		_set_selected(NO_TILE)
		_set_customer(chosen["id"])
	else:
		_set_customer("")
		_set_selected(chosen["tile"])
	var labels: Array = []
	for i in cands.size():
		labels.append(("▶ " if i == _pick_index else "　") + cands[i]["label"])
	pick_candidates_changed.emit(labels if cands.size() > 1 else [])
	_redraw_objects()


func _set_customer(id: String) -> void:
	if id == selected_customer:
		return
	selected_customer = id
	customer_selected.emit(id)


## The fixture instance whose footprint holds the selected tile, or "".
func selected_fixture_id() -> String:
	if selected_tile == NO_TILE or fixture_catalog == null:
		return ""
	for inst in fixtures:
		var def: Dictionary = fixture_catalog.get_type(inst["type_id"])
		if StoreGrid.footprint_cells(def["footprint"], inst["x"], inst["y"], inst["rotation"]).has(selected_tile):
			return inst["instance_id"]
	return ""


func set_overlay_mode(m: int) -> void:
	if m == overlay_mode:
		return
	overlay_mode = m
	overlay_changed.emit(m)
	_redraw_objects()


func cycle_overlay_mode() -> void:
	set_overlay_mode((overlay_mode + 1) % OverlayModel.MODE_NAMES.size())


func _redraw_objects() -> void:
	if _fixture_view != null:
		_fixture_view.queue_redraw()
	if _sign_layer != null:
		_sign_layer.queue_redraw()
	if _light_glow != null:
		_light_glow.queue_redraw()
	var layer := get_node_or_null("OverlayLayer")
	if layer != null:
		layer.queue_redraw()


func select_screen(screen_pos: Vector2) -> Vector2i:
	var c := projection.screen_to_tile(screen_pos)
	_set_selected(c if in_store(c) else NO_TILE)
	return selected_tile


## Right click / Esc: leave the build mode first, otherwise drop the selection.
func cancel() -> void:
	if mode != Mode.OBSERVE:
		cancel_requested.emit()
	else:
		clear_selection()


func clear_selection() -> void:
	_set_customer("")
	_set_selected(NO_TILE)
	pick_candidates_changed.emit([])
	_redraw_objects()


func set_ghost(cells: Array[Vector2i], access: Array[Vector2i], valid: bool, queue: Array[Vector2i] = []) -> void:
	if _selection == null:
		return
	var cell_polys: Array = []
	for c in cells:
		cell_polys.append(projection.tile_diamond(c))
	var access_polys: Array = []
	for c in access:
		access_polys.append(projection.tile_diamond(c))
	var queue_polys: Array = []
	for c in queue:
		queue_polys.append(projection.tile_diamond(c))
	_ghost = {"cells": cells, "access": access, "valid": valid, "queue": queue}
	_selection.show_ghost(cell_polys, access_polys, valid, queue_polys)


func clear_ghost() -> void:
	_ghost = {}
	if _selection != null:
		_selection.clear_ghost()


var _ghost: Dictionary = {}


func _set_selected(c: Vector2i) -> void:
	var changed := c != selected_tile
	selected_tile = c
	_update_canopy_visibility()
	if _selection != null:
		if c == NO_TILE:
			_selection.clear_selected()
		else:
			_selection.show_selected(projection.tile_diamond(c))
	if changed:
		selection_changed.emit(c)


func _on_viewport_resized() -> void:
	if store_width <= 0:
		return
	if user_moved:
		projection.clamp_to_store_area(viewport_size(), store_width, store_height)
		_refresh()
	else:
		fit_view()


## Re-derive highlight polygons after any camera/state change so they stay on their tiles.
func _refresh() -> void:
	_refresh_objects()
	if _backdrop != null and store_width > 0:
		_backdrop.sync(store_width, store_height, entrance_tiles, projection, viewport_size(), PropSprites.is_available("cherry_tree_a"))
	_sync_light_spill()
	if _walls != null and store_width > 0:
		_walls.sync(store_width, store_height, entrance_tiles, projection, viewport_size())
	if store_width > 0:
		if _ext_decor != null:
			_ext_decor.sync(store_width, store_height, entrance_tiles, fixtures, fixture_catalog, projection, viewport_size())
		if _wall_decor != null:
			_wall_decor.sync(store_width, store_height, entrance_tiles, fixtures, fixture_catalog, projection, viewport_size())
		if _front_decor != null:
			_front_decor.sync(store_width, store_height, entrance_tiles, fixtures, fixture_catalog, projection, viewport_size())
		if _facade_canopy != null:
			_facade_canopy.sync(store_width, store_height, entrance_tiles, fixtures, fixture_catalog, projection, viewport_size())
		for reg in [_reg_floor, _reg_top]:
			if reg != null:
				reg.sync(store_width, store_height, entrance_tiles, fixtures, fixture_catalog, projection, viewport_size())
	queue_redraw()


## Issue #114: the CanvasModulate carries the indoor tint over the whole world (the UI is not in this canvas), and the
## outdoor layers (street, pavement, trees, parked cars, exterior props) multiply by their own modulate so they land on
## LightingModel.outdoor() exactly. Assigned only when the value changes, so a publish does not touch them each time.
func _apply_time_tint() -> void:
	if _time_sec < 0:
		return
	var indoor := get_node_or_null("TimeTint") as CanvasModulate
	if indoor != null:
		indoor.color = LightingModel.indoor(_time_sec)
	var outdoor := LightingModel.outdoor_modulate(_time_sec)
	for layer in [_backdrop, _ext_decor, _front_decor]:
		if layer != null and layer.modulate != outdoor:
			layer.modulate = outdoor


## Storefront spill and lamp glows (LightSpill); it rebuilds only when its own key changes (see LightSpill.sync).
func _sync_light_spill() -> void:
	if _light_spill == null or store_width <= 0 or _time_sec < 0:
		return
	_light_spill.sync(_time_sec, store_width, store_height, entrance_tiles, projection, viewport_size())


## Selection, ghost and the object layers. The floor and walls (this node's own _draw) are left alone.
func _refresh_objects() -> void:
	_update_canopy_visibility()
	if _selection != null:
		if selected_tile != NO_TILE:
			_selection.show_selected(projection.tile_diamond(selected_tile))
		if hover_tile != NO_TILE:
			_selection.show_tile(projection.tile_diamond(hover_tile))
		if not _ghost.is_empty():
			set_ghost(_ghost["cells"], _ghost["access"], _ghost["valid"], _ghost["queue"])
	_redraw_objects()


func _update_canopy_visibility() -> void:
	if _facade_canopy != null:
		_facade_canopy.visible = mode == Mode.OBSERVE and selected_tile == NO_TILE and hover_tile == NO_TILE


## Floor pass (issue #61): tiles, grout, sheen, wall occlusion, then fixture contact shadows, all under
## the objects. Redrawn only when _floor_key changes (layout, camera or viewport), never per frame.
func _draw() -> void:
	if store_width <= 0:
		return
	if _backdrop == null:   # the BackdropLayer (drawn behind this node) paints the ground around the store
		draw_rect(Rect2(Vector2.ZERO, viewport_size()), OUTSIDE)
	for y in store_height:
		for x in store_width:
			var c := Vector2i(x, y)
			draw_colored_polygon(projection.tile_diamond(c), FloorStyle.tile_color(c, entrance_tiles, store_width, store_height))
	draw_multiline(FloorStyle.grout_segments(projection, store_width, store_height), FloorStyle.GROUT, maxf(1.0, projection.zoom))
	var s := FloorStyle.sheen(projection, store_width, store_height)
	draw_polygon(s["points"], s["colors"])
	for ao in FloorStyle.wall_ao(projection, store_width, store_height):
		draw_polygon(ao["points"], ao["colors"])
	for e in entrance_tiles:   # entrance mat: border inset on the mat tile
		var inset := FloorStyle.tile_inset(projection, e)
		inset.append(inset[0])
		draw_polyline(inset, FloorStyle.MAT_INSET, maxf(1.0, projection.zoom))
	FloorStyle.draw_shadows(self, projection, _shadows)
	_draw_perimeter()


## Walls are edges of the outer cells (they never occupy a cell); each entrance tile is drawn as a door segment on
## the outer edge of its tile, on whichever wall it sits (see BackdropLayer.door_segment).
func _draw_perimeter() -> void:
	var w := store_width - 0.5
	var h := store_height - 0.5
	var corners := [
		projection.world_to_screen(-0.5, -0.5), projection.world_to_screen(w, -0.5),
		projection.world_to_screen(w, h), projection.world_to_screen(-0.5, h),
	]
	var line_w := 4.0 * maxf(projection.zoom, 0.75)
	for i in 4:
		draw_line(corners[i], corners[(i + 1) % 4], WALL, line_w)
	for t in entrance_tiles:
		var seg := BackdropLayer.door_segment(t, store_width, store_height)
		draw_line(projection.world_to_screen(seg[0].x, seg[0].y), projection.world_to_screen(seg[1].x, seg[1].y), DOOR, line_w * 1.5)
