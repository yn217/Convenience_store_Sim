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
	$Layout/TopHUD.custom_minimum_size.y = UiTheme.HUD_HEIGHT
	_palette.custom_minimum_size.x = UiTheme.PALETTE_WIDTH
	_inspector.custom_minimum_size.x = UiTheme.INSPECTOR_WIDTH
	_store.custom_minimum_size.x = UiTheme.STORE_MIN_WIDTH
	_tab_palette.pressed.connect(func(): show_compact_panel(SidePanel.PALETTE))
	_tab_inspector.pressed.connect(func(): show_compact_panel(SidePanel.INSPECTOR))
	resized.connect(apply_layout)
	show_selection(Vector2i(-1, -1))
	apply_layout()


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
