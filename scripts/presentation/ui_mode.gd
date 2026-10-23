class_name UiMode
extends RefCounted
## Pure state machine for the store screen modes (UI redesign Phase 1, docs/qa/UI_REDESIGN_PLAN.md section 5).
## No nodes: MainLayout feeds it events and shows the panels that match `mode`.
##   NORMAL   store + top HUD + thin left rail + bottom summary
##   BUILD    build palette at the left (entered from the rail 店舗 or B)
##   SELECTED inspector at the right with the selection cards only
##   SCREEN   tabbed management window over a dimmed store (商品 / 経営 / データ / 設定)
## Build mode wins over selection: select_fixture() and select_customer() do nothing while BUILD.

enum Mode { NORMAL, BUILD, SELECTED, SCREEN }

var mode: Mode = Mode.NORMAL
## The open tab while mode == SCREEN (empty otherwise).
var screen_tab: String = ""
## The mode to return to when the screen closes.
var _return_mode: Mode = Mode.NORMAL


## 店舗 / B: enter build mode from NORMAL or SELECTED. Ignored in SCREEN.
func open_build() -> void:
	if mode == Mode.NORMAL or mode == Mode.SELECTED:
		mode = Mode.BUILD


## Esc / close button: leaves BUILD or SELECTED for NORMAL, closes SCREEN and returns to the previous mode.
func close() -> void:
	match mode:
		Mode.BUILD, Mode.SELECTED:
			mode = Mode.NORMAL
		Mode.SCREEN:
			close_screen()


## A fixture or customer was picked. Keeps BUILD (placement wins) and SCREEN untouched.
func select_fixture() -> void:
	if mode == Mode.NORMAL or mode == Mode.SELECTED:
		mode = Mode.SELECTED


func select_customer() -> void:
	select_fixture()


## Empty floor click or cleared selection: SELECTED returns to NORMAL.
func deselect() -> void:
	if mode == Mode.SELECTED:
		mode = Mode.NORMAL


## Opens a management tab. Switches tab if the screen is already open.
func open_screen(tab: String) -> void:
	if mode != Mode.SCREEN:
		_return_mode = mode
		mode = Mode.SCREEN
	screen_tab = tab


## Closes the management window and returns to the mode that was active when it opened.
func close_screen() -> void:
	if mode != Mode.SCREEN:
		return
	mode = _return_mode
	screen_tab = ""


func is_build() -> bool:
	return mode == Mode.BUILD


func is_selected() -> bool:
	return mode == Mode.SELECTED


func is_screen() -> bool:
	return mode == Mode.SCREEN


func mode_name() -> String:
	return Mode.keys()[mode]
