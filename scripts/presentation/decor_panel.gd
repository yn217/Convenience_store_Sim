class_name DecorPanel
extends VBoxContainer
## 店先の飾り (user's decision 2026-11-14): the storefront decorations (DecorCatalog) with their price and 置く, or
## 片付ける once bought. Looks only, and the panel says so. It sits in the 販促 card; PromotionController hands it the
## snapshot. BUY_DECOR / REMOVE_DECOR go through AppRoot.

const HEADING := "店先の飾り（見た目だけ。売上は変わりません）"

var _app: Node
var _seq := 0
var _rows: VBoxContainer
var _status: Label
var _key := []


func setup(app: Node) -> void:
	_app = app
	name = "DecorPanel"
	add_theme_constant_override("separation", 6)
	var heading := Label.new()
	heading.text = HEADING
	heading.theme_type_variation = &"CardTitle"
	add_child(heading)
	_rows = VBoxContainer.new()
	_rows.name = "DecorRows"
	add_child(_rows)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)


func apply_snapshot(snap: Dictionary) -> void:
	if _rows == null:
		return
	var bought: Array = snap.get("decor", [])
	var cash := int(snap.get("cash_yen", 0))
	var key := [bought.duplicate(), cash]
	if key == _key:
		return
	_key = key
	for n in _rows.get_children():
		n.queue_free()
	for d in DecorCatalog.items():
		var id := String(d["decor_id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "%s　%s\n%s" % [d["name_ja"], GameHud.format_yen(int(d["price_yen"])), d["description_ja"]]
		row.add_child(l)
		var b := Button.new()
		if bought.has(id):
			b.name = "RemoveDecor_" + id
			b.text = "片付ける"
			b.pressed.connect(remove.bind(id))
		else:
			b.name = "BuyDecor_" + id
			b.text = "置く"
			b.disabled = int(d["price_yen"]) > cash
			if b.disabled:
				b.tooltip_text = "資金が足りません"
			b.pressed.connect(buy.bind(id))
		row.add_child(b)
		_rows.add_child(row)


func buy(decor_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_decor_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"BUY_DECOR", "decor_id": decor_id})
	_status.text = "店先に飾りました。" if r.ok else "置けません（%s）" % CommandMessages.text(r.code, r.message_key)
	return r


func remove(decor_id: String) -> CommandResult:
	_seq += 1
	var r: CommandResult = _app.run_command({"command_id": "ui_decor_rm_%d_%d" % [Time.get_ticks_usec(), _seq], "kind": &"REMOVE_DECOR", "decor_id": decor_id})
	_status.text = "片付けました（代金は戻りません）。" if r.ok else "片付けられません（%s）" % CommandMessages.text(r.code, r.message_key)
	return r
