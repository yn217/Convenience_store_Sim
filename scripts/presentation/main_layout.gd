extends Control
## Screen shell (UI redesign Phase 1, docs/qa/UI_REDESIGN_PLAN.md): top HUD, a thin left rail, the store view and a
## compact bottom summary. The build palette (BUILD), the selection inspector (SELECTED) and the tabbed management
## window (SCREEN) appear only in their UiMode; the transitions are in ui_mode.gd. Card contents stay where the
## controllers built them, except that the cards not about the selection move into the management tabs.

const SCREEN_TABS := ["商品", "経営", "店員", "データ", "設定"]
## Rail entry id -> management tab it opens. 店舗 is not here: it toggles build mode.
const RAIL_TAB := {"goods": "商品", "order": "商品", "management": "経営", "data": "データ", "settings": "設定"}
## Section title text -> management tab. Cards not listed here stay in the selection inspector.
const TAB_OF_SECTION := {
	"在庫": "商品", "販売価格": "商品",
	"営業": "経営", "販促": "経営", "媒体広告": "経営", "店頭くじ": "経営", "今日のイベント": "経営", "はじめかた・目標": "経営",
	"日次レポート": "データ", "売れ筋ランキング": "データ",
	"店員": "店員",
	"演出・音": "設定", "表示モード (O)": "設定", "セーブ / ロード": "設定",
}
const INSPECTOR_CARD := "インスペクタ"
const GAP := 12                                  # floating gap: from the window edges and the HUD, and between floating panels
const BOTTOM_HEIGHT := 108                       # the summary cards (MetricBar.HEIGHT = 96) plus the gap under them (12)
const WINDOW_SIZE := Vector2(980, 640)
## Tab id -> icon (UiIcons) on the window's tab buttons.
const TAB_ICONS := {"商品": "box", "経営": "wallet", "店員": "users", "データ": "bar-chart", "設定": "gear"}
## Management tab <-> the mockup chrome's tab / menu ids.
const CHROME_TAB := {"商品": "goods", "経営": "management", "店員": "staff", "データ": "data", "設定": "settings"}
## Section title -> ribbon colour in the window (the rest alternate blue / brown).
const RIBBON_BROWN := ["販売価格", "販促", "店頭くじ", "売れ筋ランキング", "表示モード (O)"]
const NO_TILE := Vector2i(-1, -1)
## The mockup chrome's edges (MockupChrome): the top bar's bottom, the bottom bar's height, the menu's right edge.
const CHROME_TOP := 64
const CHROME_BOTTOM := 158
const CHROME_MENU_RIGHT := 236

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
var _chrome: MockupChrome     # the mockup chrome (2026-11-01); null when its images are missing
var _window_header: Control


func _ready() -> void:
	var close_guard := WindowCloseGuard.new()
	close_guard.name = "WindowCloseGuard"
	add_child(close_guard)
	theme = UiTheme.build()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette = $Layout/MainArea/BuildPalette
	_inspector = $Layout/MainArea/FixtureInspector
	_store = $Layout/MainArea/StoreViewport
	_world = $Layout/MainArea/StoreViewport/SubViewport/StoreWorld
	_state_label = $Layout/TopHUD.find_child("StateLabel", true, false) as Label   # inside the badge in the HUD row
	_selection_label = $Layout/MainArea/FixtureInspector/Scroll/Body/Details/SelectionLabel
	_nav = LeftNav.new()
	$Layout/MainArea.add_child(_nav)
	_nav.item_pressed.connect(_on_rail_pressed)
	# Bottom summary: the four metric cards only, one slim strip at the bottom of the screen.
	var metrics := MetricBar.new()
	$Layout.add_child(metrics)
	_summary = metrics
	_floats = FloatCards.new()
	add_child(_floats)
	_floats.setup()
	_floats.jump_requested.connect(_on_alert_jump)
	_build_screen_window()
	_build_chrome()
	_layout_overlay()
	# The inspector window follows its content height: refit when its content or the window size changes.
	_inspector.get_node("Scroll/Body").minimum_size_changed.connect(_fit_inspector)
	_palette.get_node("Body").minimum_size_changed.connect(_fit_palette)
	_palette.get_node("Body/Scroll/TypeList").minimum_size_changed.connect(_fit_palette)
	resized.connect(_fit_inspector)
	resized.connect(_fit_palette)
	_fit_inspector()
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
	if _chrome != null:
		_mockup_goods_page.call_deferred()
		_mockup_data_page.call_deferred()


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
	var rail_right := _place_rail()
	_fit_palette()
	# Notification column: toasts start under the HUD; the card stack sits above the summary strip.
	_floats.column_top = UiTheme.HUD_HEIGHT + GAP
	_floats.column_bottom = BOTTOM_HEIGHT + GAP
	_anchor_column(_inspector, MARGIN, UiTheme.INSPECTOR_WIDTH, true)
	_fit_inspector()
	# The summary is one centred row of cards, 12 px above the bottom edge; the row itself takes no clicks.
	_summary.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_summary.offset_left = GAP
	_summary.offset_right = -GAP
	_summary.offset_top = -BOTTOM_HEIGHT
	_summary.offset_bottom = -GAP
	_summary.mouse_filter = Control.MOUSE_FILTER_STOP   # the band is one real strip: it takes the mouse (it sits outside the store's safe area)
	# Camera safe area: the store is fitted between the rail and the right edge, under the HUD and above the summary,
	# so it sits centred in the space the floating UI leaves. Panels that open later overlay the store.
	_world.safe_inset = Vector4(rail_right + GAP, UiTheme.HUD_HEIGHT + GAP, GAP, BOTTOM_HEIGHT)
	if _chrome != null:   # the mockup's menu, top bar and bottom bar take more room
		_world.safe_inset = Vector4(CHROME_MENU_RIGHT + GAP, CHROME_TOP + GAP, GAP, CHROME_BOTTOM + GAP)
		_floats.column_top = CHROME_TOP + GAP
		_floats.column_bottom = CHROME_BOTTOM + GAP
	_world.fit_view()


## The rail's right edge (it floats GAP in from the left edge).
func _rail_right() -> float:
	return GAP + LeftNav.WIDTH


## The rail floats at the top left, under the HUD, and is only as tall as its entries. Returns its right edge.
func _place_rail() -> float:
	_nav.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_nav.offset_left = GAP
	_nav.offset_top = UiTheme.HUD_HEIGHT + GAP
	_nav.offset_right = _rail_right()
	_nav.offset_bottom = _nav.offset_top + _nav.get_combined_minimum_size().y
	return _nav.offset_right


const MARGIN := 8
## The inspector window hangs from just under the HUD, with this gap above and below, and is only as tall as its content.
const INSPECTOR_TOP := 12


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


## The build catalog hangs under the HUD at the rail's right edge, as tall as its content (tabs, cards and footer),
## up to the space above the summary strip. Past that its grid scrolls inside the window. Only the window's own rect
## takes mouse input, so the store below it stays clickable. Only the palette's anchors, offsets and scroll minimum
## size change here.
func _fit_palette() -> void:
	if _palette == null:
		return
	var scroll := _palette.get_node("Body/Scroll") as ScrollContainer
	var body := _palette.get_node("Body") as Control
	var grid := scroll.get_node("TypeList") as Control
	var height := size.y if size.y > 0.0 else get_viewport_rect().size.y
	var top := UiTheme.HUD_HEIGHT + GAP
	var bottom := BOTTOM_HEIGHT
	if _chrome != null:   # the mockup's taller bars
		top = CHROME_TOP + GAP
		bottom = CHROME_BOTTOM
	var room := maxf(height - top - bottom - GAP, 0.0)
	var frame := _palette.get_theme_stylebox("panel").get_minimum_size().y
	scroll.custom_minimum_size.y = 0.0
	var fixed := body.get_combined_minimum_size().y   # everything but the grid (the scroll has no minimum yet)
	scroll.custom_minimum_size.y = minf(grid.get_combined_minimum_size().y, maxf(room - frame - fixed, 0.0))
	var wanted := body.get_combined_minimum_size().y + frame
	var left: float = (float(CHROME_MENU_RIGHT) if _chrome != null else _rail_right()) + GAP   # right of the menu, never under it
	_palette.anchor_top = 0.0
	_palette.anchor_bottom = 0.0
	_palette.anchor_left = 0.0
	_palette.anchor_right = 0.0
	_palette.offset_top = top
	_palette.offset_bottom = top + minf(wanted, room)
	_palette.offset_left = left
	_palette.offset_right = left + UiTheme.PALETTE_WIDTH


## The inspector hangs from under the HUD and is as tall as its content, up to the space above the summary strip.
## Past that space its scroll area takes the rest, so only the window's own rect takes mouse input; the store below
## it stays clickable. Only the inspector's anchors, offsets and scroll minimum size change here.
func _fit_inspector() -> void:
	if _inspector == null:
		return
	var scroll := _inspector.get_node("Scroll") as ScrollContainer
	var body := scroll.get_node("Body") as Control
	var height := size.y if size.y > 0.0 else get_viewport_rect().size.y
	var top := (CHROME_TOP if _chrome != null else UiTheme.HUD_HEIGHT) + INSPECTOR_TOP
	var room := maxf(height - top - (CHROME_BOTTOM if _chrome != null else BOTTOM_HEIGHT) - INSPECTOR_TOP, 0.0)
	var frame := _inspector.get_theme_stylebox("panel").get_minimum_size().y
	scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, maxf(room - frame, 0.0))
	var wanted := scroll.get_combined_minimum_size().y + frame
	_inspector.anchor_top = 0.0
	_inspector.anchor_bottom = 0.0
	_inspector.offset_top = top
	_inspector.offset_bottom = top + minf(wanted, room)


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
		var guide := get_node_or_null("ProgressionController")
		if guide != null and guide.has_method("request_pilot_cue"):
			guide.request_pilot_cue("layout_help", {})


func close_build() -> void:
	var build := get_node_or_null("BuildController")
	if build != null:
		build.cancel_mode()   # leave any pending placement or move
	ui.close()
	var guide := get_node_or_null("ProgressionController")
	if guide != null and guide.has_method("clear_pilot_cue"):
		guide.clear_pilot_cue()
	_world.clear_selection()
	_apply_mode()


func open_screen_tab(tab: String) -> void:
	ui.open_screen(tab)
	_apply_mode()
	var guide := get_node_or_null("ProgressionController")
	if guide != null and guide.has_method("request_pilot_cue"):
		if tab == "店員":
			guide.request_pilot_cue("staff_schedule_open", {})
		elif tab == "経営":
			var app := get_node_or_null("AppRoot") as AppRoot
			if app != null and app.state.business_state == GameState.SETUP:
				guide.request_pilot_cue("opening_checklist", {})


func close_screen() -> void:
	ui.close_screen()
	var guide := get_node_or_null("ProgressionController")
	if guide != null and guide.has_method("clear_pilot_cue"):
		guide.clear_pilot_cue()
	_sync_selection()


## Name of the current UiMode (NORMAL, BUILD, SELECTED, SCREEN) for tests and the capture tool.
func mode_name() -> String:
	return ui.mode_name()


func _on_rail_pressed(id: String) -> void:
	if id == "store":
		toggle_build()
	elif id == "order":
		open_goods_order()
	else:
		open_screen_tab(RAIL_TAB[id])


## 発注 (rail) and similar shortcuts: the 商品 tab, scrolled to the order section (StockController).
func open_goods_order() -> void:
	open_screen_tab("商品")
	var guide := get_node_or_null("ProgressionController")
	if guide != null and guide.has_method("request_pilot_cue"):
		guide.request_pilot_cue("order_help", {})
	var stock := get_node_or_null("StockController")
	if stock != null and stock.has_method("order_section"):
		_reveal.call_deferred(stock.order_section())


## 商品を補充 in the inspector: the 商品 tab, scrolled to the restock section of the selected fixture.
func open_restock_section() -> void:
	open_screen_tab("商品")
	var guide := get_node_or_null("ProgressionController")
	if guide != null and guide.has_method("request_pilot_cue"):
		guide.request_pilot_cue("restock_help", {})
	var stock := get_node_or_null("StockController")
	if stock != null and stock.has_method("restock_section"):
		_reveal.call_deferred(stock.restock_section())


## 価格変更 on an inspector row: the 商品 tab, scrolled to that SKU's price field, which takes focus.
func open_price_for(sku_id: String) -> void:
	open_screen_tab("商品")
	var pricer := get_node_or_null("PriceController")
	if pricer != null and pricer.has_method("focus_sku"):
		pricer.focus_sku(sku_id)
		_reveal.call_deferred(pricer.price_field(sku_id))


## 価格を設定 in the inspector: the 商品 tab, scrolled to the price field of the first SKU in `sku_ids` (the fixture's
## shelf products), which takes focus. The other fields of the price list stay where they are.
func open_prices_for(sku_ids: Array) -> void:
	open_screen_tab("商品")
	var pricer := get_node_or_null("PriceController")
	if pricer == null or sku_ids.is_empty():
		return
	var first := String(sku_ids[0])
	pricer.focus_sku(first)
	_reveal.call_deferred(pricer.price_field(first))


## Scrolls every ScrollContainer above `control` so the control is in view. Runs deferred, after the layout is up.
func _reveal(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var node := control.get_parent()
	while node != null and node != self:
		if node is ScrollContainer:
			(node as ScrollContainer).ensure_control_visible(control)
		node = node.get_parent()


## The 在庫アラート row's 選ぶ button: selects that fixture, as a click on it would (build mode gives way first).
func _on_alert_jump(tile: Vector2i) -> void:
	if ui.is_build():
		close_build()
	_world.select_screen(_world.projection.tile_center(tile))


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
	_inspector.visible = ui.is_selected()
	# The notification column keeps clear of the open inspector (it hangs on the right edge).
	if _floats != null:
		_floats.column_right = GAP + (MARGIN + UiTheme.INSPECTOR_WIDTH + GAP if ui.is_selected() else 0)
	_fit_inspector()
	_dimmer.visible = ui.is_screen()
	_window.visible = ui.is_screen()
	var event_controller := get_node_or_null("EventController")
	if event_controller != null and event_controller.has_method("sync_assistant_suppression"):
		event_controller.sync_assistant_suppression(ui.is_screen() and ui.screen_tab == "経営")
	# The build palette occupies the same lower-left area as the assistant bubble.
	# Keep the assistant stage out of the way while the palette is interactive;
	# normal mode still uses the left-aligned, display-only cropped portrait.
	var guide := get_node_or_null("ProgressionController")
	if guide != null and guide.has_method("set_suppressed"):
		guide.set_suppressed(ui.is_build(), "build")
	if _chrome != null:
		_chrome.set_window(ui.is_screen(), CHROME_TAB.get(ui.screen_tab, "goods"))
		var stock := get_node_or_null("StockController")
		if stock != null and stock.backroom_panel != null and not (ui.is_screen() and ui.screen_tab == "商品"):
			stock.backroom_panel.visible = false   # the list belongs to the 商品 tab
		_chrome.set_nav("store" if ui.is_build() or ui.is_selected() else (CHROME_TAB.get(ui.screen_tab, "") if ui.is_screen() else ""))
	if ui.is_screen():
		_ribbon_headings()
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


# --- mockup chrome ----------------------------------------------------------------------------------------

## The 2026-11-01 mockup's chrome over the store (MockupChrome): it replaces the look of the HUD band, the rail and the
## summary strip (those stay in the tree, hidden, and still hold the state the tests read), and frames the management
## window, whose pages are laid into the frame's content area.
func _build_chrome() -> void:
	if not MockupChrome.available():
		return
	_chrome = MockupChrome.new()
	add_child(_chrome)
	move_child(_chrome, _dimmer.get_index() + 1)   # above the dimmer (the menu stays usable), under the window pages
	$Layout/TopHUD.visible = false
	_nav.visible = false
	_summary.visible = false
	_dimmer.color = Color(0, 0, 0, 0)   # the mockup does not dim the store behind the window
	_window_header.visible = false
	_tabs.tabs_visible = false
	_window.theme_type_variation = &""
	_window.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_window.grow_horizontal = Control.GROW_DIRECTION_END
	_window.grow_vertical = Control.GROW_DIRECTION_END
	_window.custom_minimum_size = MockupChrome.CONTENT.size
	_window.position = MockupChrome.CONTENT.position
	_window.size = MockupChrome.CONTENT.size
	var hud := $Layout/TopHUD as GameHud
	_chrome.nav_pressed.connect(_on_chrome_nav)
	_chrome.tab_pressed.connect(_on_chrome_tab)
	_chrome.close_pressed.connect(close_screen)
	_chrome.speed_pressed.connect(func(speed: int): hud.speed_requested.emit(speed))
	_chrome.pause_pressed.connect(func(): hud._on_pause_pressed())
	_chrome.corner_pressed.connect(_on_chrome_corner)
	_chrome.guide.connect("go_requested", Callable(self, "_on_guide_go"))
	_chrome.guide.connect("open_requested", func():
		var business := get_node_or_null("BusinessController")
		if business != null:
			business.start_business())


## The 商品 page as the mockup draws it (in code): the 在庫・発注 card with the order controls on it and the 販売価格
## card with its column headings and the price rows in a scrolling list. The old 在庫 / 販売価格 cards stay in the page,
## hidden (their controls moved here).
func _mockup_goods_page() -> void:
	var page_box: VBoxContainer = _pages["商品"]
	var page := Control.new()
	page.name = "GoodsMockup"
	page.custom_minimum_size = MockupChrome.CONTENT.size - Vector2(2, 2)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	var cards := page_box.get_children()
	page_box.add_child(page)
	page_box.move_child(page, 0)
	MockStyle.card(page, Rect2(8, 6, 1012, 142))   # its top edge runs behind the ribbon, above the バックヤード line
	MockStyle.ribbon(page, Rect2(0, 2, 290, 50), "在庫・発注", MockStyle.RIBBON_BLUE, "box3d", 28)
	MockStyle.picture(page, MockStyle.glyph("shelf", 96), Rect2(338, 16, 38, 34), Color("4a3a3a"))   # drawn 31x27 (the glyph has a margin)
	MockStyle.card(page, Rect2(8, 162, 1012, 276))   # likewise behind its ribbon, above the column headings
	var sub := MockStyle.ribbon(page, Rect2(214, 172, 248, 40), "（店頭の価格を変更します）", [Color("a0605a"), Color("7a3a3a")], "", 16)
	(sub.get_child(0) as Label).position.x = 28   # the text starts after the main ribbon's point
	(sub.get_child(0) as Label).position.y -= 3   # level with the main ribbon's heading, as in the mockup
	MockStyle.ribbon(page, Rect2(0, 166, 232, 52), "販売価格", MockStyle.RIBBON_BROWN, "tag", 30)
	for h in [["販売価格", 470, 120], ["原価", 610, 92], ["粗利", 700, 96], ["粗利率", 790, 102]]:
		MockStyle.label(page, h[0], Rect2(h[1], 178, h[2], 34), 16, MockStyle.INK, HORIZONTAL_ALIGNMENT_CENTER, "Black")
	var stock := get_node_or_null("StockController")
	var price := get_node_or_null("PriceController")
	if stock != null:
		stock.mockup_layout(page)
	if price != null:
		price.mockup_list(page, Rect2(12, 214, 1004, 222))
	for c in cards:
		(c as Control).visible = false
	(page_box.get_parent() as ScrollContainer).vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


## The データ tab as the mockup draws it (MockDataPage). 詳細 shows the old report cards under it (kept, scrolled to).
func _mockup_data_page() -> void:
	var page_box: VBoxContainer = _pages["データ"]
	var page := MockDataPage.new()
	var cards := page_box.get_children()
	page_box.add_child(page)
	page_box.move_child(page, 0)
	for c in cards:
		(c as Control).visible = false
	var reporter := get_node_or_null("ReportController")
	if reporter != null:
		reporter.mockup_page = page
	page.details_requested.connect(func():
		for c in cards:
			(c as Control).visible = not (c as Control).visible
		page.visible = not page.visible)


func _on_chrome_nav(id: String) -> void:
	match id:
		"store", "equipment":
			if ui.is_screen():
				close_screen()
			toggle_build()
		"order":
			open_goods_order()
		"achievements":
			open_screen_tab("経営")   # the goals and today's mission live there
		_:
			_open_chrome_tab(id)


func _on_chrome_tab(id: String) -> void:
	if id == "store":
		close_screen()
		toggle_build()
		return
	_open_chrome_tab(id)


func _open_chrome_tab(id: String) -> void:
	for tab in CHROME_TAB:
		if CHROME_TAB[tab] == id:
			open_screen_tab(tab)
			return


## 開店までの手順's buttons: 店舗 (build mode), 発注 (the 商品 tab), 棚を選ぶ (selects the first shelf, whose card has 補充).
func _on_guide_go(where: String) -> void:
	match where:
		"build":
			if not ui.is_build():
				toggle_build()
		"goods":
			open_goods_order()
		"shelf":
			for inst in _world.fixtures:
				var def: Dictionary = _world.fixture_catalog.get_type(inst["type_id"])
				if not def.get("shelf_slots", []).is_empty():
					_on_alert_jump(Vector2i(int(inst["x"]), int(inst["y"])))
					return


func _on_chrome_corner(id: String) -> void:
	match id:
		"notices":
			_floats.visible = not _floats.visible
		"missions":
			open_screen_tab("経営")
		"save", "settings":
			open_screen_tab("設定")
		"quit":
			var returner := get_node_or_null("TitleReturnController")
			if returner != null and returner.has_method("ask_return_to_title"):
				returner.ask_return_to_title()


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
	_window.theme = UiTheme.build_window()   # the cream window look; the HUD outside keeps the dark theme
	_window.theme_type_variation = &"WindowFrame"
	_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_window.custom_minimum_size = WINDOW_SIZE
	_window.visible = false
	add_child(_window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_window.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	_window_header = header
	var mark := TextureRect.new()
	mark.texture = UiTheme.tinted(UiIcons.texture("grid", 34), UiTheme.W_TEXT)
	mark.custom_minimum_size = Vector2(34, 34)
	mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(mark)
	var title := Label.new()
	title.text = "経営管理"
	title.theme_type_variation = &"WindowTitle"
	header.add_child(title)
	var sub := Label.new()
	sub.text = "Store Management"
	sub.theme_type_variation = &"MutedLabel"
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sub)
	var close := Button.new()
	close.name = "CloseScreen"
	close.text = "×"
	close.tooltip_text = "閉じる (Esc)"
	close.theme_type_variation = &"CloseRound"
	close.custom_minimum_size = Vector2(46, 46)
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
		_tabs.set_tab_icon(_tabs.get_tab_count() - 1, UiTheme.tinted(UiIcons.texture(TAB_ICONS[tab], 22), UiTheme.W_TEXT))


## Moves the cards built by the controllers into their management tabs (by SectionTitle text). The selection
## cards stay in the inspector. Runs after style_sections, so every card is already a Card PanelContainer.
func _organize_panels() -> void:
	var body: VBoxContainer = $Layout/MainArea/FixtureInspector/Scroll/Body
	for card in body.get_children():
		var title := _card_title(card)
		if TAB_OF_SECTION.has(title):
			card.reparent(_pages[TAB_OF_SECTION[title]])
			var heading := _card_heading(card)
			if heading != null:
				(heading.get_parent() as Container).add_theme_constant_override("separation", 12)
	var overlay := get_node_or_null("OverlayController")
	var customer: Variant = overlay.get("_customer_row") if overlay != null else null   # the portrait and the line together
	var inspector_card := _find_card(body, INSPECTOR_CARD)
	if customer is Node and inspector_card != null:
		(customer as Node).reparent(inspector_card.get_child(0))   # the selected customer's line lives in the window
	if inspector_card != null:
		# The window is the inspector frame itself: the card inside it is transparent so there is one frame, not two.
		inspector_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var inspector_title := inspector_card.find_children("*", "Label", true, false)[0] as Label
		_add_close_button(inspector_title, close_inspector)
		_add_heading_icon(inspector_title, "person")
	var palette_title := $Layout/MainArea/BuildPalette/Body/Title as Label
	_add_close_button(palette_title, close_build)
	_add_heading_icon(palette_title, "store")
	_style_action_buttons()


## Every SectionTitle in the window gets its ribbon (cards added after setup too, e.g. ゲームを終了・タイトルへ).
func _ribbon_headings() -> void:
	for l in _window.find_children("*", "Label", true, false):
		var label := l as Label
		if label.theme_type_variation == &"SectionTitle" and not label.has_theme_stylebox_override("normal"):
			UiTheme.window_ribbon(label, UiTheme.W_RIBBON_BROWN if label.text in RIBBON_BROWN else UiTheme.W_RIBBON_BLUE)


## The card's SectionTitle label (its first Label), or null.
func _card_heading(card: Node) -> Label:
	for l in card.find_children("*", "Label", true, false):
		if (l as Label).theme_type_variation == &"SectionTitle":
			return l
	return null


## Puts a small icon in front of a window heading (GUI v3: header with icon). The heading keeps its node and its row.
func _add_heading_icon(title: Label, icon_name: String) -> void:
	var row := title.get_parent()
	var icon := TextureRect.new()
	icon.name = "HeadingIcon"
	icon.texture = UiIcons.texture(icon_name, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = UiTheme.WARM
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	row.move_child(icon, title.get_index())


## Move / rotate / remove in the inspector get their icons (the actions keep their behaviour and disabled states).
func _style_action_buttons() -> void:
	for pair in [["MoveButton", "move"], ["RotateButton", "rotate"], ["RemoveButton", "trash"]]:
		var b := find_child(pair[0], true, false) as Button
		if b == null:
			continue
		b.icon = UiIcons.texture(pair[1], 18)
		b.expand_icon = false
		b.custom_minimum_size.y = 36


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
