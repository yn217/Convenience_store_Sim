class_name FixtureSprites
extends RefCounted
## Manifest-driven fixture sprites (#9). Loads the visual variant chosen by VisualVariants (the painted pilot when
## approved or overridden, else assets/generated/fixtures/<type>/<type>_a.visual.json) and its imported layer
## textures once; types without a manifest return {} (placeholder boxes).

const DIR := "res://assets/generated/fixtures"
const LAYER_ORDER_BELOW := ["shadow", "body"]
const LAYER_ORDER_ABOVE := ["glass_front"]

var _cache: Dictionary = {}
var _prefs: Dictionary = VisualVariants.load_preferences()
var _generation: int = VisualVariants.generation


## Drops the cached entries when the visual variant override changed. True when they were dropped.
func refresh() -> bool:
	if _generation == VisualVariants.generation:
		return false
	_generation = VisualVariants.generation
	_cache.clear()
	return true


## {"anchor": Vector2, "layers": {name: Texture2D}, "slots": {slot_name: Vector2}, "variant": String,
## "baked": bool} or {}. "baked" means the products are drawn into the sprite (no item drawing on top).
func rotation_entry(type_id: String, rotation: int) -> Dictionary:
	refresh()
	var key := "%s/%d" % [type_id, rotation]
	if _cache.has(key):
		return _cache[key]
	var entry := _load(type_id, rotation)
	_cache[key] = entry
	return entry


## The same variant's picture for a stock state (HALF / EMPTY, issue #91): the manifest beside the chosen one, named
## <visual>_<state>.visual.json. {} when that variant has no picture for the state.
func state_entry(type_id: String, rotation: int, state: String) -> Dictionary:
	refresh()
	var key := "%s/%s/%d" % [state, type_id, rotation]
	if not _cache.has(key):
		var choice := VisualVariants.resolve(_prefs, "fixtures", type_id, VisualVariants.override())
		var path := str(choice["path"]).replace(".visual.json", "_%s.visual.json" % state.to_lower())
		_cache[key] = _load_path(path, rotation, str(choice["variant"])) if path != str(choice["path"]) else {}
	return _cache[key]


## The base variant's entry ("a", items drawn live), whatever variant is chosen: what a shelf with products baked into
## its picture falls back to when it is not full (issue #91: no HALF / EMPTY picture yet).
func base_entry(type_id: String, rotation: int) -> Dictionary:
	refresh()
	var key := "base/%s/%d" % [type_id, rotation]
	if not _cache.has(key):
		_cache[key] = _load(type_id, rotation, VisualVariants.BASE)
	return _cache[key]


func has_sprites(type_id: String) -> bool:
	var choice := VisualVariants.resolve(_prefs, "fixtures", type_id, VisualVariants.override())
	return str(choice["path"]) != "" and FileAccess.file_exists(str(choice["path"]))


func _load(type_id: String, rotation: int, forced: String = "") -> Dictionary:
	var choice := VisualVariants.resolve(_prefs, "fixtures", type_id, forced if forced != "" else VisualVariants.override())
	return _load_path(str(choice["path"]), rotation, str(choice["variant"]))


func _load_path(path: String, rotation: int, variant: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var rot: Dictionary = json.data["rotations"].get(str(rotation), {})
	if rot.is_empty():
		return {}
	var layers := {}
	for name in rot["layers"]:
		var layer_path := "%s/%s" % [path.get_base_dir(), rot["layers"][name]]
		if not ResourceLoader.exists(layer_path):
			return {}
		var tex := load(layer_path) as Texture2D
		if tex == null:
			return {}
		layers[name] = tex
	var slots := {}
	for k in rot.get("slot_anchors_px", {}):
		slots[k] = Vector2(rot["slot_anchors_px"][k][0], rot["slot_anchors_px"][k][1])
	return {
		"anchor": Vector2(rot["anchor_px"][0], rot["anchor_px"][1]),
		"layers": layers,
		"slots": slots,
		"variant": variant,
		"baked": VisualVariants.products_baked(json.data),
	}
