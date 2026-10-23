extends Control
## Screen shell (04 §1): top HUD, build palette | store view | inspector. Below
## COMPACT_WIDTH only one side panel is open at a time, switched by two tab buttons.

enum SidePanel { PALETTE, INSPECTOR }

var compact_panel: SidePanel = SidePanel.PALETTE

@onready var _palette: Control = $Layout/MainArea/BuildPalette
@onready var _inspector: Control = $Layout/MainArea/FixtureInspector
@onready var _store: Control = $Layout/MainArea/StoreViewport
@onready var _tab_palette: Button = $Layout/TopHUD/Row/PaletteTab
@onready var _tab_inspector: Button = $Layout/TopHUD/Row/InspectorTab
@onready var _selection_label: Label = $Layout/MainArea/FixtureInspector/Scroll/Body/SelectionLabel


func _ready() -> void:
	theme = UiTheme.build()
	var nav := LeftNav.new()
	$Layout/MainArea.add_child(nav)
	$Layout/MainArea.move_child(nav, 0)
	$Layout.add_child(CommandBar.new())
	$Layout.add_child(MetricBar.new())
	var floats := FloatCards.new()
	add_child(floats)
	floats.setup(_store)
	$Layout/TopHUD.custom_minimum_size.y = UiTheme.HUD_HEIGHT
	_palette.custom_minimum_size.x = UiTheme.PALETTE_WIDTH
	_inspector.custom_minimum_size.x = UiTheme.INSPECTOR_WIDTH
	_store.custom_minimum_size.x = UiTheme.STORE_MIN_WIDTH
	_tab_palette.pressed.connect(func(): show_compact_panel(SidePanel.PALETTE))
	_tab_inspector.pressed.connect(func(): show_compact_panel(SidePanel.INSPECTOR))
	resized.connect(apply_layout)
	show_selection(Vector2i(-1, -1))
	apply_layout()
	style_sections.call_deferred()


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


func is_compact() -> bool:
	return size.x < UiTheme.COMPACT_WIDTH


func show_compact_panel(panel: SidePanel) -> void:
	compact_panel = panel
	apply_layout()


func apply_layout() -> void:
	var compact := is_compact()
	_tab_palette.visible = compact
	_tab_inspector.visible = compact
	_palette.visible = not compact or compact_panel == SidePanel.PALETTE
	_inspector.visible = not compact or compact_panel == SidePanel.INSPECTOR


func show_selection(tile: Vector2i) -> void:
	_selection_label.text = "未選択" if tile.x < 0 else "選択タイル (%d, %d)" % [tile.x, tile.y]
