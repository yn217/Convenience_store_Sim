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


## Section headings of the side panels (the 20 px title labels the controllers add) get the warm heading style
## and a rule above them, so the inspector reads as stacked cards without moving any node.
func style_sections() -> void:
	for body in [$Layout/MainArea/FixtureInspector/Scroll/Body, $Layout/MainArea/BuildPalette/Body]:
		var first := true
		for child in body.get_children():
			if not (child is Label) or child.theme_type_variation == &"SectionTitle":
				continue
			if not child.has_theme_font_size_override("font_size") or child.get_theme_font_size("font_size") != 20:
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
