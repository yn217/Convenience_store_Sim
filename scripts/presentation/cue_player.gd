class_name CuePlayer
extends Node
## Plays CueRequests (14): toasts, sales pop-ups, confetti, register glow, door flash, pickup / empty-handed
## marks and the synthesized sounds. Display only - it cannot fail a sale, move stock or change money,
## and a missing sound, a muted game or `reduce_motion` only drops the decoration: the text notice stays.
## Toast rules (levels, limit, merging, lifetimes) are in NotificationPolicy.
## Limits (14 §4): 3 toasts, 6 sales pop-ups, 80 particles, 8 simultaneous sounds.

const MAX_TOASTS := NotificationPolicy.MAX_VISIBLE
const MAX_FLOATS := 6
const MAX_PARTICLES := 80
const MAX_SFX := 8
const CONFETTI_PER_CUE := 40
const SETTINGS_VERSION := 1

## Sounds start OFF: the player turns them on once to hear them, and the choice is saved.
var muted := true
var reduce_motion := false
var sfx_volume := 0.8
var settings_path := "user://settings.json"

## Live decorations, advanced with real time (UI clock). Read by CueLayer.
var notices := NotificationPolicy.new()
## Live toasts (the policy's list): text, level, age, ttl.
var toasts: Array[Dictionary]:
	get:
		return notices.items
## Sales pop-ups, one per register: text, yen, count, register_id, age, ttl.
var floats: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var glows: Array[Dictionary] = []
var marks: Array[Dictionary] = []   # pickup / empty-handed icons above a customer
var door_flash := 0.0
## Everything handled, newest last (a test hook and the base of the "recent notices" list).
var handled: Array[String] = []
var sfx_played: Array[String] = []

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _rng := RandomNumberGenerator.new()   # visuals only: confetti never touches the game's seeded streams


func _ready() -> void:
	add_to_group("cue_player")
	_rng.seed = 7
	load_settings()
	for i in MAX_SFX:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_build_settings_ui()


func _process(delta: float) -> void:
	advance(delta)


## Cue requests from PresentationEventBridge.map().
func play(requests: Array) -> void:
	for r in requests:
		_play_one(r)


func _play_one(r: Dictionary) -> void:
	handled.append(r["cue_id"])
	if handled.size() > 256:
		handled.pop_front()
	var payload: Dictionary = r["payload"]
	var cue_id: String = r["cue_id"]
	var fixture_name := _fixture_name(String(payload.get("fixture_id", "")))
	if CueText.toast_text(cue_id, {}) != "":
		var text_for := func(amount: int, count: int) -> String:
			var merged := payload.duplicate()
			merged["qty"] = amount
			merged["count"] = count
			return CueText.toast_text(cue_id, merged, fixture_name)
		notices.offer(cue_id, CueText.level_of(cue_id, String(r["priority"])), int(payload.get("qty", 1)), text_for)
	match cue_id:
		"checkout_success":
			glows.append({"register_id": payload.get("register_id", ""), "age": 0.0, "ttl": float(r["duration_seconds"])})
			if glows.size() > MAX_FLOATS:
				glows.pop_front()
			NotificationPolicy.add_sale(floats, String(payload.get("register_id", "")), int(payload.get("revenue_yen", 0)), String(payload.get("name", "")))
			while floats.size() > MAX_FLOATS:
				floats.pop_front()
		"customer_enter":
			door_flash = float(r["duration_seconds"])
		"product_pickup":
			_add_mark("pick", String(payload.get("customer_id", "")), float(r["duration_seconds"]), {
				"category": String(payload.get("category", "")), "fixture_id": String(payload.get("fixture_id", "")), "sku_id": String(payload.get("sku_id", "")),
			})
		"empty_handed":
			_add_mark("empty", String(payload.get("customer_id", "")), float(r["duration_seconds"]))
		"milestone_celebrate":
			if not reduce_motion:
				_confetti()
	if r["sfx_key"] != null:
		_sfx(String(r["sfx_key"]), r["priority"])


## Closes one error toast (a click on it). Other levels are not dismissed by hand.
func dismiss_toast(item: Dictionary) -> void:
	if item.get("level", "") == "error":
		notices.dismiss(item)


func _add_mark(kind: String, customer_id: String, ttl: float, extra: Dictionary = {}) -> void:
	var mark := {"kind": kind, "customer_id": customer_id, "age": 0.0, "ttl": ttl}
	mark.merge(extra)
	marks.append(mark)
	while marks.size() > MAX_FLOATS * 2:
		marks.pop_front()


func _confetti() -> void:
	for i in CONFETTI_PER_CUE:
		if particles.size() >= MAX_PARTICLES:
			break
		particles.append({
			"pos": Vector2(_rng.randf_range(0.2, 0.8), -0.05), "vel": Vector2(_rng.randf_range(-0.08, 0.08), _rng.randf_range(0.25, 0.5)),
			"hue": _rng.randf(), "age": 0.0, "ttl": 1.2,
		})


## Real-time step of every decoration.
func advance(delta: float) -> void:
	notices.advance(delta)
	for list in [floats, glows, marks, particles]:
		for item in list:
			item["age"] += delta
			if item.has("vel"):
				item["pos"] += item["vel"] * delta
		var keep: Array = list.filter(func(x): return x["age"] < x["ttl"])
		list.clear()
		list.append_array(keep)
	door_flash = maxf(0.0, door_flash - delta)


func has_motion() -> bool:
	return not (toasts.is_empty() and floats.is_empty() and particles.is_empty() and glows.is_empty() and marks.is_empty()) or door_flash > 0.0


func _sfx(key: String, priority: String) -> void:
	if muted or not SfxBank.has(key) or _players.is_empty():
		return
	var free: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			free = p
			break
	if free == null:
		if priority == "normal" or priority == "ambient":
			return   # 14 §4: past eight voices the normal / ambient sounds are dropped
		free = _players[0]
	if not _streams.has(key):
		_streams[key] = SfxBank.stream(key)
	free.stream = _streams[key]
	free.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))
	free.play()
	sfx_played.append(key)
	if sfx_played.size() > 256:
		sfx_played.pop_front()


func _fixture_name(instance_id: String) -> String:
	if instance_id == "":
		return ""
	var world := get_node_or_null("../Layout/MainArea/StoreViewport/SubViewport/StoreWorld")
	if world == null or world.fixture_catalog == null:
		return ""
	for inst in world.fixtures:
		if inst["instance_id"] == instance_id:
			return world.fixture_catalog.get_type(inst["type_id"])["display_name"]
	return ""


# ---------------------------------------------------------------- settings

func load_settings() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SETTINGS_VERSION:
		return
	muted = bool(data.get("muted", true))
	reduce_motion = bool(data.get("reduce_motion", false))
	UiFx.reduced = reduce_motion
	sfx_volume = clampf(float(data.get("sfx_volume", 0.8)), 0.0, 1.0)


func save_settings() -> void:
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"version": SETTINGS_VERSION, "muted": muted, "reduce_motion": reduce_motion, "sfx_volume": sfx_volume}))


func set_muted(value: bool) -> void:
	muted = value
	save_settings()


func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	UiFx.reduced = value   # the UI's hover, press and value-pop tweens follow the same setting
	if value:
		particles.clear()
		floats.clear()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()


func _build_settings_ui() -> void:
	var body := get_node_or_null("../Layout/MainArea/FixtureInspector/Scroll/Body")
	if body == null:
		return
	var title := Label.new()
	title.text = "演出・音"
	title.add_theme_font_size_override("font_size", 20)
	body.add_child(title)
	var mute := CheckButton.new()
	mute.text = "効果音ミュート"
	mute.button_pressed = muted
	mute.toggled.connect(set_muted)
	body.add_child(mute)
	var calm := CheckButton.new()
	calm.text = "動きを減らす"
	calm.button_pressed = reduce_motion
	calm.toggled.connect(set_reduce_motion)
	body.add_child(calm)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = sfx_volume
	vol.value_changed.connect(set_sfx_volume)
	body.add_child(vol)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "ミュートや動きを減らす設定でも、通知の文字は表示されます。効果音の音量は上のスライダーです。"
	body.add_child(note)
