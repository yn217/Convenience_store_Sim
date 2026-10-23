class_name SaveController
extends Node
## Save / load slots in the inspector. Presentation only: it sends SAVE_GAME / LOAD_GAME through
## AppRoot and shows the answer. After a damaged main file it offers the backup generation.

var _app: Node
var _slot: OptionButton
var _backup_button: Button
var _status: Label
var _seq: int = 0
var _last_failed_slot: String = ""


func setup(app: Node) -> void:
	_app = app
	var body: VBoxContainer = get_node("../Layout/MainArea/FixtureInspector/Body")
	var title := Label.new()
	title.text = "セーブ / ロード"
	title.add_theme_font_size_override("font_size", 20)
	body.add_child(title)
	_slot = OptionButton.new()
	_slot.fit_to_longest_item = false
	_slot.custom_minimum_size = Vector2(60, 0)
	for id in SaveStore.SLOTS:
		_slot.add_item("スロット %s" % id.right(1))
		_slot.set_item_metadata(_slot.item_count - 1, id)
	var row := HBoxContainer.new()
	var save := Button.new()
	save.text = "保存"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(save_slot)
	var load_button := Button.new()
	load_button.text = "読込"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(func(): load_slot(false))
	row.add_child(save)
	row.add_child(load_button)
	_backup_button = Button.new()
	_backup_button.text = "バックアップから読込"
	_backup_button.visible = false
	_backup_button.pressed.connect(func(): load_slot(true))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in [_slot, row, _backup_button, _status]:
		body.add_child(c)


func _slot_id() -> String:
	return _slot.get_item_metadata(_slot.selected)


func save_slot() -> CommandResult:
	var r := _send({"kind": &"SAVE_GAME", "slot_id": _slot_id()})
	_status.text = "保存しました（%s）" % _slot.get_item_text(_slot.selected) if r.ok else CommandMessages.text(r.code, r.message_key)
	return r


func load_slot(use_backup: bool) -> CommandResult:
	var id := _slot_id()
	var r := _send({"kind": &"LOAD_GAME", "slot_id": id, "use_backup": use_backup})
	if r.ok:
		_status.text = "読み込みました（%s%s）" % [_slot.get_item_text(_slot.selected), "・バックアップ" if use_backup else ""]
		_backup_button.visible = false
	else:
		_status.text = CommandMessages.text(r.code, r.message_key)
		_last_failed_slot = id
		_backup_button.visible = not use_backup and SaveStore.has_backup(id, _app.save_dir)
	return r


func _send(cmd: Dictionary) -> CommandResult:
	_seq += 1
	cmd["command_id"] = "ui_save_%d" % _seq
	return _app.run_command(cmd)
