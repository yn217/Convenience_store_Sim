extends Control
## Screen shell (UI redesign Phase 1, docs/qa/UI_REDESIGN_PLAN.md): top HUD, a thin left rail, the store view and a
## compact bottom summary. The build palette (BUILD), the selection inspector (SELECTED) and the tabbed management
## window (SCREEN) appear only in their UiMode; the transitions are in ui_mode.gd. Card contents stay where the
## controllers built them, except that the cards not about the selection move into the management tabs.

const SCREEN_TABS := ["商品", "経営", "データ", "設定"]
## Rail entry id -> management tab it opens. 店舗 is not here: it toggles build mode.
const RAIL_TAB := {"goods": "商品", "management": "経営", "data": "データ", "settings": "設定"}
## Section title text -> management tab. Cards not listed here stay in the selection inspector.
const TAB_OF_SECTION := {
	"在庫": "商品", "販売価格": "商品",
	"営業": "経営", "今日のイベント": "経営", "はじめかた・目標": "経営",
	"日次レポート": "データ",
	"演出・音": "設定", "表示モード (O)": "設定", "セーブ / ロード": "設定",
}
const SELECTION_CARD := "選択中の什器"
const INSPECTOR_CARD := "インスペクタ"
const BOTTOM_HEIGHT := 72
const WINDOW_SIZE := Vector2(780, 600)
const NO_TILE := Vector2i(-1, -1)

var ui := UiMode.new()
var _nav: LeftNav
var _palette: Control
var _inspector: Control
var _store: Control
var _world: Node2D
var _state_label: Label
var _summary: Control
var _floats: FloatCards
var _selection_label: Label
var _dimmer: ColorRect
var _window: PanelContainer
var _tabs: TabContainer
var _pages: Dictionary = {}   # tab name -> VBoxContainer the cards are moved into


func _ready() -> void:
	theme = UiTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette = $Layout/MainArea/BuildPalette
	_inspector = $Layout/MainArea/FixtureInspector
	_store = $Layout/MainArea/StoreViewport
	_world = $Layout/MainArea/StoreViewport/SubViewport/StoreWorld
	_state_label = $Layout/TopHUD/Row/StateLabel
	_selection_label = $Layout/MainArea/FixtureInspector/Scroll/Body/SelectionLabel
	_nav = LeftNav.new()
	$Layout/MainArea.add_child(_nav)
	_nav.item_pressed.connect(_on_rail_pressed)
	# Bottom summary: the four metric cards only, one slim strip at the bottom of the screen.
	var metrics := MetricBar.new()
	$Layout.add_child(metrics)
	_summary = metrics
	_floats = FloatCards.new()
	add_child(_floats)
	_floats.setup(_store)
	_build_screen_window()
	_layout_overlay()
	_nav.set_active("")
	# The state badge (営業中 / 準備中 …) opens the 経営 tab, where 営業開始 / 閉店 live.
	_state_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_state_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_state_label.tooltip_text = "クリックで経営画面（営業開始・閉店）"
	_state_label.gui_input.connect(_on_state_gui_input)
	_world.selection_changed.connect(func(_t): _sync_selection())
	_world.customer_selected.connect(func(_id): _sync_selection())
	show_selection(NO_TILE)
	_apply_mode()
	style_sections.call_deferred()
	_organize_panels.call_deferred()


## Overlay design: the store world fills the whole window; every panel anchors to an edge and floats over it.
## Only panels (and the dimmer in SCREEN) take mouse input, so the world receives clicks everywhere else.
## Nothing here changes the world viewport size: opening or closing a panel never moves the camera.
func _layout_overlay() -> void:
	var area := $Layout/MainArea as Control
	area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_store.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_store.custom_minimum_size = Vector2.ZERO
	area.move_child(_store, 0)   # the world is the bottom layer
	var layout := $Layout as Control
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.move_child(area, 0)   # layer order: world (MainArea) < HUD and summary < modal layers added later
	var hud := $Layout/TopHUD as Control
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_bottom = UiTheme.HUD_HEIGHT
	hud.custom_minimum_size.y = UiTheme.HUD_HEIGHT
	var rail := LeftNav.WIDTH
	_anchor_column(_nav, 0.0, rail, false)
	_anchor_column(_palette, rail + MARGIN, UiTheme.PALETTE_WIDTH, false)
	_anchor_column(_inspector, MARGIN, UiTheme.INSPECTOR_WIDTH, true)
	_summary.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_summary.offset_left = rail + MARGIN
	_summary.offset_right = -MARGIN
	_summary.offset_top = -BOTTOM_HEIGHT
	_summary.offset_bottom = -MARGIN
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE   # the strip itself takes no clicks; its cards may
	# Camera safe area: the store is fitted between the HUD, the rail and the summary; panels overlay it.
	_world.safe_inset = Vector4(rail + MARGIN, UiTheme.HUD_HEIGHT, 0, BOTTOM_HEIGHT)
	_world.fit_view()


const MARGIN := 8


## A floating column that spans the height between the HUD and the summary. `x` is its left edge from the left
## window edge, or (when from_right) the gap to the right window edge. Both the rail and the panels use this.
func _anchor_column(panel: Control, x: float, width: float, from_right: bool) -> void:
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_top = UiTheme.HUD_HEIGHT + MARGIN
	panel.offset_bottom = -(BOTTOM_HEIGHT + MARGIN)
	panel.anchor_left = 1.0 if from_right else 0.0
	panel.anchor_right = panel.anchor_left
	panel.offset_left = -x - width if from_right else x
	panel.offset_right = -x if from_right else x + width


## Esc leaves the current mode; B toggles build mode (both are ignored while a window is open for B).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_on_escape()
	elif event.keycode == KEY_B and not ui.is_screen():
		toggle_build()


func _on_escape() -> void:
	if ui.is_screen():
		close_screen()
	elif ui.is_build():
		close_build()
	elif ui.is_selected():
		_world.clear_selection()
		ui.deselect()
		_apply_mode()


# --- mode commands (also used by the rail, the B key and tests) ----------------------------------------------

func toggle_build() -> void:
	if ui.is_build():
		close_build()
	else:
		ui.open_build()
		_apply_mode()


func close_build() -> void:
	var build := get_node_or_null("BuildController")
	if build != null:
		build.cancel_mode()   # leave any pending placement or move
	ui.close()
	_world.clear_selection()
	_apply_mode()


func open_screen_tab(tab: String) -> void:
	ui.open_screen(tab)
	_apply_mode()


func close_screen() -> void:
	ui.close_screen()
	_sync_selection()


## Name of the current UiMode (NORMAL, BUILD, SELECTED, SCREEN) for tests and the capture tool.
func mode_name() -> String:
	return ui.mode_name()


func _on_rail_pressed(id: String) -> void:
	if id == "store":
		toggle_build()
	else:
		open_screen_tab(RAIL_TAB[id])


func _on_state_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_screen_tab("経営")


## A fixture or customer selection (store signals) moves NORMAL to SELECTED and back. BUILD and SCREEN keep their mode.
func _sync_selection() -> void:
	if _world == null:
		return
	if _world.selected_tile != NO_TILE or _world.selected_customer != "":
		ui.select_fixture()
	else:
		ui.deselect()
	_apply_mode()


func _apply_mode() -> void:
	_palette.visible = ui.is_build()
	# Notification cards start clear of the rail and the HUD, and of the build palette while it is open.
	if _floats != null:
		_floats.inset = Vector2(LeftNav.WIDTH + (UiTheme.PALETTE_WIDTH + MARGIN if ui.is_build() else 0), UiTheme.HUD_HEIGHT)
	_inspector.visible = ui.is_selected()
	_dimmer.visible = ui.is_screen()
	_window.visible = ui.is_screen()
	if ui.is_screen():
		var tab_index := SCREEN_TABS.find(ui.screen_tab)
		if tab_index >= 0:
			_tabs.current_tab = tab_index
	var active := ""
	if ui.is_build() or ui.is_selected():
		active = "store"
	elif ui.is_screen():
		active = _rail_id_of_tab(ui.screen_tab)
	if _nav != null:
		_nav.set_active(active)


func _rail_id_of_tab(tab: String) -> String:
	for id in RAIL_TAB:
		if RAIL_TAB[id] == tab:
			return id
	return ""


# --- management window -------------------------------------------------------------------------------------

func _build_screen_window() -> void:
	_dimmer = ColorRect.new()
	_dimmer.name = "ScreenDimmer"
	_dimmer.color = Color(0, 0, 0, 0.55)
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP   # blocks the store and the rail while a window is open
	_dimmer.visible = false
	add_child(_dimmer)
	_window = PanelContainer.new()
	_window.name = "ManagementWindow"
	_window.theme_type_variation = &"Card"
	_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_window.custom_minimum_size = WINDOW_SIZE
	_window.visible = false
	add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_window.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "経営管理"
	title.theme_type_variation = &"SectionTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.name = "CloseScreen"
	close.text = "閉じる ×"
	close.tooltip_text = "Esc"
	close.pressed.connect(close_screen)
	header.add_child(close)
	_tabs = TabContainer.new()
	_tabs.name = "ScreenTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	for tab in SCREEN_TABS:
		var scroll := ScrollContainer.new()
		scroll.name = tab
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tabs.add_child(scroll)
		var page := VBoxContainer.new()
		page.name = "Body"
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		scroll.add_child(page)
		_pages[tab] = page


## Moves the cards built by the controllers into their management tabs (by SectionTitle text). The selection
## cards stay in the inspector. Runs after style_sections, so every card is already a Card PanelContainer.
func _organize_panels() -> void:
	var body: VBoxContainer = $Layout/MainArea/FixtureInspector/Scroll/Body
	for card in body.get_children():
		var title := _card_title(card)
		if TAB_OF_SECTION.has(title):
			card.reparent(_pages[TAB_OF_SECTION[title]])
	var overlay := get_node_or_null("OverlayController")
	var customer: Variant = overlay.get("_customer") if overlay != null else null
	var selection_card := _find_card(body, SELECTION_CARD)
	if customer is Node and selection_card != null:
		(customer as Node).reparent(selection_card.get_child(0))   # the selected customer's line lives under the fixture
	var inspector_card := _find_card(body, INSPECTOR_CARD)
	if inspector_card != null:
		_add_close_button(inspector_card.find_children("*", "Label", true, false)[0], close_inspector)
	_add_close_button($Layout/MainArea/BuildPalette/Body/Title, close_build)


func close_inspector() -> void:
	_world.clear_selection()
	ui.deselect()
	_apply_mode()


## SectionTitle text of a card (the first heading label inside it), or "".
func _card_title(card: Node) -> String:
	for n in card.find_children("*", "Label", true, false):
		if (n as Label).theme_type_variation == &"SectionTitle" or (n as Label).get_theme_font_size("font_size") == 20:
			return (n as Label).text
	return ""


func _find_card(body: Node, title: String) -> Node:
	for card in body.get_children():
		if _card_title(card) == title:
			return card
	return null


## Puts a × button on the same row as a heading label. The label keeps its node and moves into a row with the button.
func _add_close_button(title: Label, on_pressed: Callable) -> void:
	var parent := title.get_parent()
	var row := HBoxContainer.new()
	row.name = "HeadingRow"
	parent.add_child(row)
	parent.move_child(row, title.get_index())
	title.reparent(row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "×"
	close.tooltip_text = "閉じる (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(30, 0)
	close.pressed.connect(on_pressed)
	row.add_child(close)


## Section headings get the warm heading style. The inspector sections become cards: each SectionTitle
## label and the nodes after it (up to the next title) move, in order, into one Card PanelContainer.
## The palette keeps the flat list with a rule above each heading.
func style_sections() -> void:
	var inspector: VBoxContainer = $Layout/MainArea/FixtureInspector/Scroll/Body
	for child in inspector.get_children():
		if _is_section_title(child):
			child.theme_type_variation = &"SectionTitle"
	_wrap_cards(inspector)
	_separate_palette_sections($Layout/MainArea/BuildPalette/Body)


func _is_section_title(node: Node) -> bool:
	if not (node is Label):
		return false
	if node.theme_type_variation == &"SectionTitle":
		return true
	return node.has_theme_font_size_override("font_size") and node.get_theme_font_size("font_size") == 20


func _wrap_cards(body: VBoxContainer) -> void:
	var sections: Array = []   # one Array of nodes per section, title first; nodes above the first title stay put
	for child in body.get_children():
		if child is Label and child.theme_type_variation == &"SectionTitle":
			sections.append([])
		if not sections.is_empty():
			sections[-1].append(child)
	for section in sections:
		var card := PanelContainer.new()
		card.theme_type_variation = &"Card"
		var column := VBoxContainer.new()
		card.add_child(column)
		body.add_child(card)
		body.move_child(card, (section[0] as Node).get_index())
		for node in section:
			(node as Node).reparent(column)


func _separate_palette_sections(body: VBoxContainer) -> void:
	var first := true
	for child in body.get_children():
		if not _is_section_title(child):
			continue
		child.theme_type_variation = &"SectionTitle"
		if not first:
			var rule := HSeparator.new()
			body.add_child(rule)
			body.move_child(rule, child.get_index())
		first = false


func show_selection(tile: Vector2i) -> void:
	var label := _selection_label
	label.text = "未選択" if tile.x < 0 else "選択タイル (%d, %d)" % [tile.x, tile.y]
