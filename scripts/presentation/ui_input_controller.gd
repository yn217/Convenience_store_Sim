class_name UiInputController
extends Node
## Store viewport input (04 §2): wheel = pointer-centred zoom, middle drag or
## Space + left drag = pan, left click = select tile, right click / Esc = cancel,
## F = fit whole store. Space alone does nothing. Sits inside the SubViewport, so it only
## sees pointer events that really landed on the store view (UI panels never forward theirs).

const ZOOM_STEP := 1.1

@export var world_path: NodePath = ^".."

var _world: Node2D
var _space_held := false
var _panning := false


func _ready() -> void:
	_world = get_node(world_path)


func _input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()


## Returns true when the event was consumed. Public so tests can drive it directly.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if _panning:
			_world.pan_by(event.relative)
		else:
			_world.set_hover_screen(event.position)
		return _panning
	if event is InputEventMouseButton:
		return _on_button(event)
	if event is InputEventKey:
		return _on_key(event)
	return false


func _on_button(event: InputEventMouseButton) -> bool:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				var steps := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				_world.zoom_at(event.position, _world.projection.zoom * pow(ZOOM_STEP, steps * maxf(event.factor, 1.0)))
			return true
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			return true
		MOUSE_BUTTON_LEFT:
			if event.pressed and _space_held:
				_panning = true
			elif event.pressed:
				_world.select_screen(event.position)
			elif _panning:
				_panning = false
			return true
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_world.clear_selection()
			return true
	return false


func _on_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_SPACE:
		_space_held = event.pressed
		return false   # Space alone is not an action; never swallow it.
	if not event.pressed or event.echo:
		return false
	match event.keycode:
		KEY_ESCAPE:
			_world.clear_selection()
			return true
		KEY_F:
			_world.fit_view()
			return true
	return false
