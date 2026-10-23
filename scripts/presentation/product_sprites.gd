class_name ProductSprites
extends RefCounted
## Manifest-driven product overlay sprites.
## A visual_id maps to a shared shape template; stock quantity and LOD remain runtime state.

const DIR := "res://assets/generated/products"
const MANIFEST := DIR + "/products_manifest.json"

var _manifest: Dictionary = {}
var _cache: Dictionary = {}
var _loaded := false


## Returns {"sku_id", "shape_id", "texture": Texture2D, "rotation": int} or {}.
func entry(visual_id: String, rotation: int) -> Dictionary:
	_load_manifest()
	var key := "%s/%d" % [visual_id, posmod(rotation, 4)]
	if _cache.has(key):
		return _cache[key]
	var spec: Dictionary = _manifest.get(visual_id, {})
	if spec.is_empty():
		_cache[key] = {}
		return {}
	var rel := String(spec.get("directions", {}).get(str(posmod(rotation, 4)), ""))
	if rel.is_empty():
		_cache[key] = {}
		return {}
	var tex := load("%s/%s" % [DIR, rel]) as Texture2D
	if tex == null:
		_cache[key] = {}
		return {}
	var out := {"sku_id": String(spec.get("sku_id", "")), "shape_id": String(spec.get("shape_id", "")), "texture": tex, "rotation": posmod(rotation, 4)}
	_cache[key] = out
	return out


func has_visual(visual_id: String) -> bool:
	_load_manifest()
	return _manifest.has(visual_id)


func visual_count() -> int:
	_load_manifest()
	return _manifest.size()


func _load_manifest() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(MANIFEST)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var root: Dictionary = json.data
	if typeof(root.get("products", {})) == TYPE_DICTIONARY:
		_manifest = root["products"]
