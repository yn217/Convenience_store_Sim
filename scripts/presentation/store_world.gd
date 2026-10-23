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

enum Mode { OBSERVE, PLACE, MOVE }

const NO_TILE := Vector2i(-1, -1)
const FLOOR_A := Color(0.80, 0.80, 0.76)
const FLOOR_B := Color(0.74, 0.74, 0.70)
const WALL := Color(0.25, 0.25, 0.28)
const DOOR := Color(0.25, 0.60, 0.85)
const OUTSIDE := Color(0.55, 0.62, 0.50)
const MIN_VISIBLE_PX := 128.0

var store_width: int = 0
var store_height: int = 0
var revision: int = -1
var entrance_tiles: Array[Vector2i] = []
var fixtures: Array = []
var fixture_catalog: FixtureCatalog
var projection := IsoProjection.new()
var hover_tile := NO_TILE
var selected_tile := NO_TILE
var mode: Mode = Mode.OBSERVE
## True once the player zoomed/panned; resizing then keeps their view instead of refitting.
var user_moved := false

@onready var _selection: Node2D = $SelectionOverlay
@onready var _fixture_view: Node2D = $ObjectSortRoot/FixturePresenter


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)


func apply_snapshot(snapshot: Dictionary) -> void:
	var first := store_width <= 0
	store_width = int(snapshot["store_width"])
	store_height = int(snapshot["store_height"])
	revision = int(snapshot["revision"])
	entrance_tiles.clear()
	for t in snapshot.get("entrance_tiles", []):
		entrance_tiles.append(t)
	fixtures = snapshot.get("fixtures", [])
	if first or not in_store(selected_tile):
		_set_selected(NO_TILE)
	if first:
		fit_view()
	else:
		_refresh()


func tile_count() -> int:
	return store_width * store_height


func in_store(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < store_width and c.y < store_height


func viewport_size() -> Vector2:
	return get_viewport_rect().size


## F key: whole floor visible and centred, forgetting manual zoom/pan.
func fit_view() -> void:
	if store_width <= 0:
		return
	user_moved = false
	projection.fit_floor(viewport_size(), store_width, store_height)
	_refresh()


func zoom_at(pivot: Vector2, new_zoom: float) -> void:
	user_moved = true
	projection.zoom_at(pivot, new_zoom)
	projection.clamp_to_viewport(viewport_size(), store_width, store_height, MIN_VISIBLE_PX)
	_refresh()


func pan_by(delta: Vector2) -> void:
	user_moved = true
	projection.pan(delta)
	projection.clamp_to_viewport(viewport_size(), store_width, store_height, MIN_VISIBLE_PX)
	_refresh()


## Highlights the store tile under `screen_pos` (viewport coordinates).
## Returns the hovered tile, or NO_TILE when the point is outside the floor.
func set_hover_screen(screen_pos: Vector2) -> Vector2i:
	var c := projection.screen_to_tile(screen_pos)
	var tile := c if in_store(c) else NO_TILE
	var changed := tile != hover_tile
	hover_tile = tile
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
		_set_selected(tile)
	elif tile != NO_TILE:
		tile_clicked.emit(tile)


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
	_set_selected(NO_TILE)


func set_ghost(cells: Array[Vector2i], access: Array[Vector2i], valid: bool) -> void:
	if _selection == null:
		return
	var cell_polys: Array = []
	for c in cells:
		cell_polys.append(projection.tile_diamond(c))
	var access_polys: Array = []
	for c in access:
		access_polys.append(projection.tile_diamond(c))
	_ghost = {"cells": cells, "access": access, "valid": valid}
	_selection.show_ghost(cell_polys, access_polys, valid)


func clear_ghost() -> void:
	_ghost = {}
	if _selection != null:
		_selection.clear_ghost()


var _ghost: Dictionary = {}


func _set_selected(c: Vector2i) -> void:
	var changed := c != selected_tile
	selected_tile = c
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
		projection.clamp_to_viewport(viewport_size(), store_width, store_height, MIN_VISIBLE_PX)
		_refresh()
	else:
		fit_view()


## Re-derive highlight polygons after any camera/state change so they stay on their tiles.
func _refresh() -> void:
	if _selection != null:
		if selected_tile != NO_TILE:
			_selection.show_selected(projection.tile_diamond(selected_tile))
		if hover_tile != NO_TILE:
			_selection.show_tile(projection.tile_diamond(hover_tile))
		if not _ghost.is_empty():
			set_ghost(_ghost["cells"], _ghost["access"], _ghost["valid"])
	if _fixture_view != null:
		_fixture_view.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if store_width <= 0:
		return
	draw_rect(Rect2(Vector2.ZERO, viewport_size()), OUTSIDE)
	for y in store_height:
		for x in store_width:
			var c := Vector2i(x, y)
			draw_colored_polygon(projection.tile_diamond(c), FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
	_draw_perimeter()


## Walls are edges of the outer cells (they never occupy a cell); the west entrance
## tiles are drawn as door segments on the x = -0.5 edge.
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
		draw_line(projection.world_to_screen(-0.5, t.y - 0.5), projection.world_to_screen(-0.5, t.y + 0.5), DOOR, line_w * 1.5)
