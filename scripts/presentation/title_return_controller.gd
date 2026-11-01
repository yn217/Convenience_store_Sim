class_name TitleReturnController
extends Node
## Settings-tab return to title. A confirmation pauses the SceneTree without
## modifying the stored game speed or Domain state.

const TITLE_SCENE := "res://scenes/title/Title.tscn"
const DEFAULT_SAVE_SLOT := "slot_1"

var _dialog: ConfirmationDialog
var _slot_to_save := DEFAULT_SAVE_SLOT
var _transition_pending := false


func _ready() -> void:
	# MainLayout builds its settings TabContainer in _ready; install after it.
	_install_ui.call_deferred()


func _install_ui() -> void:
	var root := get_parent() as Control
	var pages: Dictionary = root.get("_pages")
	var settings: VBoxContainer = pages.get("設定") as VBoxContainer
	if settings == null:
		push_error("TitleReturnController: settings tab is unavailable")
		return
	var card := PanelContainer.new()
	card.name = "TitleReturnCard"
	card.theme_type_variation = &"Card"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var caption := Label.new()
	caption.text = "ゲームを終了・タイトルへ"
	caption.theme_type_variation = &"SectionTitle"
	column.add_child(caption)
	var hint := Label.new()
	hint.text = "ゲーム中の状態は自動保存されません。保存して戻ることもできます。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)
	var button := Button.new()
	button.name = "ReturnToTitle"
	button.text = "タイトルに戻る"
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(ask_return_to_title)
	column.add_child(button)
	settings.add_child(card)
	_dialog = ConfirmationDialog.new()
	_dialog.name = "ReturnToTitleDialog"
	_dialog.title = "タイトルに戻りますか？"
	_dialog.ok_button_text = "保存せず戻る"
	_dialog.cancel_button_text = "キャンセル"
	_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_dialog.add_button("保存して戻る", false, "save_and_return")
	_dialog.custom_action.connect(_on_dialog_action)
	_dialog.confirmed.connect(_leave_to_title)
	_dialog.canceled.connect(_cancel_return)
	root.add_child(_dialog)


func ask_return_to_title() -> void:
	if _dialog == null or _transition_pending:
		return
	var app := get_parent().get_node_or_null("AppRoot") as AppRoot
	if app == null or app.state == null:
		return
	_slot_to_save = SaveStore.latest_slot(app.save_dir)
	if _slot_to_save.is_empty():
		_slot_to_save = DEFAULT_SAVE_SLOT
	_dialog.dialog_text = (
		"未保存の進行状況はタイトルに戻ると失われます。\n\n" +
		"「保存して戻る」は %s に現在の状態を保存します。既存の保存があれば上書きします。" % _slot_to_save
	)
	_dialog.popup_centered(Vector2i(660, 230))
	# This preserves state.speed_setting (including x4) when the user cancels.
	get_tree().paused = true


func _on_dialog_action(action: StringName) -> void:
	if action != &"save_and_return" or _transition_pending:
		return
	var app := get_parent().get_node_or_null("AppRoot") as AppRoot
	if app == null:
		_cancel_return()
		return
	var result := app.run_command({
		"kind": &"SAVE_GAME",
		"slot_id": _slot_to_save,
		"command_id": "return_title_save_%d" % Time.get_ticks_usec()
	})
	if result.ok:
		_leave_to_title()
	else:
		_dialog.dialog_text = "保存に失敗しました。ゲームへ戻って保存先を確認してください。\n\n" + CommandMessages.text(result.code, result.message_key)
		_dialog.popup_centered(Vector2i(660, 230))


func _cancel_return() -> void:
	if not _transition_pending:
		get_tree().paused = false


func _leave_to_title() -> void:
	if _transition_pending:
		return
	_transition_pending = true
	# The title must not launch directly into a stale Continue slot.
	AppRoot.start_slot = ""
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", TITLE_SCENE)


func _exit_tree() -> void:
	# Safeguard when the scene is removed while a dialog is open.
	if get_tree() != null:
		get_tree().paused = false
