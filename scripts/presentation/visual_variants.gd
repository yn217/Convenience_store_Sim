class_name VisualVariants
extends RefCounted
## Presentation-only choice of the visual variant per asset (painted pilot vs the current art).
## Preferences come from res://data/presentation/visual_variants.json: per asset id an ordered list of variant
## ids, tried first to last. A variant is usable when its manifest exists and it is runtime_approved, or when a
## dev override is on (then approval is waived). Nothing usable -> the base variant "a" (the current art).
## Dev override, highest first: the `--visual-variant=NAME` user argument, then the 設定 toggle
## 'テスト用の画像を使う' (settings.json "test_images" -> TEST_VARIANT).
## Never reads or writes simulation state.

const PREFS_PATH := "res://data/presentation/visual_variants.json"
const BASE := "a"
const TEST_VARIANT := "painted_v1"
const ARG_PREFIX := "--visual-variant="
## Built-in manifest templates for the base variant, so the game works without the preferences file.
const BASE_PATHS := {
	"fixtures": "res://assets/generated/fixtures/{id}/{id}_a.visual.json",
	"props": "res://assets/generated/props/{id}/{id}.visual.json",
}

## Bumped whenever the override changes, so cached sprite entries know to reload.
static var generation := 0
static var _test_images := false
static var _arg_parsed := false
static var _arg_variant := ""


static func load_preferences(path: String = PREFS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if typeof(data) == TYPE_DICTIONARY else {}


## The variant named by a `--visual-variant=NAME` argument in `args`, or "" when there is none.
static func arg_override(args: Array) -> String:
	for a in args:
		if str(a).begins_with(ARG_PREFIX):
			return str(a).trim_prefix(ARG_PREFIX)
	return ""


## The active dev override: the command line argument first, then the settings toggle, else "".
static func override() -> String:
	if not _arg_parsed:
		_arg_parsed = true
		_arg_variant = arg_override(OS.get_cmdline_user_args())
	if _arg_variant != "":
		return _arg_variant
	return TEST_VARIANT if _test_images else ""


static func test_images() -> bool:
	return _test_images


static func set_test_images(on: bool) -> void:
	if on != _test_images:
		_test_images = on
		generation += 1


## Manifest path of one variant of one asset, or "" when the variant has no template.
static func manifest_path(prefs: Dictionary, kind: String, id: String, variant: String) -> String:
	var tpl = ""
	var paths = prefs.get("paths", {})
	if typeof(paths) == TYPE_DICTIONARY and typeof(paths.get(kind, null)) == TYPE_DICTIONARY:
		tpl = paths[kind].get(variant, "")
	if variant == BASE and (typeof(tpl) != TYPE_STRING or tpl == ""):
		tpl = BASE_PATHS.get(kind, "")
	if typeof(tpl) != TYPE_STRING or tpl == "":
		return ""
	return String(tpl).replace("{id}", id)


## {"variant": String, "path": String}. `path` is the chosen manifest (it may be missing for the base variant;
## callers check FileAccess.file_exists). `override_name` is the dev override ("" when off).
static func resolve(prefs: Dictionary, kind: String, id: String, override_name: String = "") -> Dictionary:
	if override_name == BASE:   # forced current art: no list, no gate
		return {"variant": BASE, "path": manifest_path(prefs, kind, id, BASE)}
	var order: Array = []
	if override_name != "":
		order.append(override_name)
	var listed = prefs.get(kind, {})
	if typeof(listed) == TYPE_DICTIONARY and typeof(listed.get(id, [])) == TYPE_ARRAY:
		for v in listed.get(id, []):
			if typeof(v) == TYPE_STRING:
				order.append(v)
	for v in order:
		var path := manifest_path(prefs, kind, id, v)
		if path != "" and _usable(path, override_name != ""):
			return {"variant": v, "path": path}
	return {"variant": BASE, "path": manifest_path(prefs, kind, id, BASE)}


## True when the manifest file exists, parses as a dictionary, and is approved for runtime use (the dev override
## waives the approval only).
static func _usable(path: String, waived: bool) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return waived or data.get("runtime_approved", false) == true


## A painted FULL variant has its products baked into the sprite: the presenter must not draw items on top.
static func products_baked(manifest: Dictionary) -> bool:
	return bool(manifest.get("products_baked", false)) or str(manifest.get("state", "")) == "FULL"
