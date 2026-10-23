class_name UiFx
extends RefCounted
## Game feel for the UI (presentation only): button hover / press tweens, value pops on changed numbers,
## alternating and selected list-row looks. Pure helpers take plain values (unit-tested); the Tween helpers only
## run on events (a pointer entering or leaving a button, a press, a value that changed). Nothing here runs per frame.
## `reduced` mirrors the reduce_motion setting (CuePlayer sets it): no scale tweens and no value pops, while the
## colour changes stay, so the state still reads.

const HOVER_SCALE := 1.04
const PRESS_SCALE := 0.96
const HOVER_TINT := Color(1.08, 1.08, 1.08, 1.0)
const PRESS_TINT := Color(0.9, 0.9, 0.9, 1.0)
const TWEEN_SECONDS := 0.08
const POP_FROM := 1.12
const POP_SECONDS := 0.25
const FLASH_UP := Color("6ef0a0")
const FLASH_DOWN := Color("ff7070")
const FLASH_NEUTRAL := Color("fff3c4")
const META_TWEEN := &"ui_fx_tween"
const META_STATE := &"ui_fx_state"
const META_FX := &"ui_fx_wired"
const META_ROW_BASE := &"ui_fx_row_base"

static var reduced := false


## Scale of a button for its pointer state: pressed sinks to 0.96, hovered lifts to 1.04, otherwise 1.
static func press_scale(hovered: bool, pressed: bool) -> float:
	if pressed:
		return PRESS_SCALE
	return HOVER_SCALE if hovered else 1.0


## Brightness multiplier for a button's pointer state (white when idle).
static func hover_tint(hovered: bool, pressed: bool) -> Color:
	if pressed:
		return PRESS_TINT
	return HOVER_TINT if hovered else Color.WHITE


## Scale of a value label `t` seconds into its pop: eases from POP_FROM down to 1, then holds at 1.
static func pop_scale(t: float) -> float:
	var k := clampf(t / POP_SECONDS, 0.0, 1.0)
	return lerpf(POP_FROM, 1.0, 1.0 - (1.0 - k) * (1.0 - k))


## +1 when the number went up, -1 when it went down, 0 when unchanged.
static func direction(previous: int, current: int) -> int:
	return signi(current - previous)


## Flash colour of a value pop: green for an increase, red for a decrease, warm white for a neutral change.
static func flash_color(dir: int) -> Color:
	if dir > 0:
		return FLASH_UP
	if dir < 0:
		return FLASH_DOWN
	return FLASH_NEUTRAL


## Wires hover and press feedback to a button once (a meta flag guards re-connection).
static func attach(b: BaseButton) -> void:
	if b == null or b.has_meta(META_FX):
		return
	b.set_meta(META_FX, true)
	b.pivot_offset = b.size * 0.5
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func(): _set_state(b, true, _is_down(b)))
	b.mouse_exited.connect(func(): _set_state(b, false, false))
	b.button_down.connect(func(): _set_state(b, true, true))
	b.button_up.connect(func(): _set_state(b, b.get_global_rect().has_point(b.get_global_mouse_position()), false))


static func _is_down(b: BaseButton) -> bool:
	return (int(b.get_meta(META_STATE, 0)) & 2) != 0


static func _set_state(b: BaseButton, hovered: bool, pressed: bool) -> void:
	b.set_meta(META_STATE, (1 if hovered else 0) | (2 if pressed else 0))
	var off := b.disabled
	var scale := 1.0 if off else press_scale(hovered, pressed)
	var tint := Color.WHITE if off else hover_tint(hovered, pressed)
	if reduced:
		b.scale = Vector2.ONE
		b.modulate = tint
		return
	var old: Variant = b.get_meta(META_TWEEN, null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "scale", Vector2.ONE * scale, TWEEN_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate", tint, TWEEN_SECONDS)
	b.set_meta(META_TWEEN, tw)


## Value pop: the label swells to POP_FROM and settles while its font flashes (green up, red down, else warm),
## then fades back to its own colour. Skipped under reduced motion and for a label outside the tree.
static func pop(label: Label, dir: int) -> void:
	if reduced or label == null or not label.is_inside_tree():
		return
	label.pivot_offset = label.size * 0.5
	var base := label.get_theme_color("font_color")
	label.add_theme_color_override("font_color", flash_color(dir))
	var tw := label.create_tween().set_parallel(true)
	tw.tween_method(func(t: float): label.scale = Vector2.ONE * pop_scale(t), 0.0, POP_SECONDS, POP_SECONDS)
	tw.tween_property(label, "theme_override_colors/font_color", base, POP_SECONDS)


## Alternating row tint for a list button: odd rows get a lighter face. The base look is kept for un-selecting.
static func stripe(b: Button, odd: bool, face: Color) -> void:
	if not odd:
		return
	var box := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if box == null:
		return
	box.bg_color = face
	b.add_theme_stylebox_override("normal", box)
	b.set_meta(META_ROW_BASE, box)


## Selected list row: the blue glow look; un-selected rows go back to their striped (or theme) face.
static func set_row_selected(b: Button, selected: bool) -> void:
	if selected:
		b.add_theme_stylebox_override("normal", UiTheme.selected_row_box())
	elif b.has_meta(META_ROW_BASE):
		b.add_theme_stylebox_override("normal", b.get_meta(META_ROW_BASE))
	else:
		b.remove_theme_stylebox_override("normal")
