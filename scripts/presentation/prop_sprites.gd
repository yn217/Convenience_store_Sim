class_name PropSprites
extends RefCounted
## Issue #110: manifest-driven static props (storefront, planters, street furniture). Loads
## assets/generated/props/<id>/<id>.visual.json once per id: the direction-0 layers (shadow, body) and the
## ground anchor. An id without a manifest or with a missing layer returns {} and the caller skips the prop.

const DIR := "res://assets/generated/props"
const LAYER_ORDER := ["shadow", "body"]

var _cache: Dictionary = {}


static func manifest_path(prop_id: String) -> String:
	return "%s/%s/%s.visual.json" % [DIR, prop_id, prop_id]


## True when the prop has a manifest on disk (cheap check used to choose between code-drawn and sprite art).
static func is_available(prop_id: String) -> bool:
	return FileAccess.file_exists(manifest_path(prop_id))


## {"layers": Array[Texture2D] (shadow first), "anchor": Vector2 (source px), "size": Vector2 (source px)} or {}.
## `rotation` 0..3 picks that art direction (props that line up along a wall or a counter, #113); 0 by default.
func texture(prop_id: String, rotation: int = 0) -> Dictionary:
	var key := "%s#%d" % [prop_id, rotation]
	if _cache.has(key):
		return _cache[key]
	var entry := _load(prop_id, rotation)
	_cache[key] = entry
	return entry


func _load(prop_id: String, rotation: int) -> Dictionary:
	var path := manifest_path(prop_id)
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var rot: Dictionary = json.data.get("rotations", {}).get(str(rotation), {})
	if rot.is_empty() or not rot.has("layers") or not rot.has("anchor_px"):
		return {}
	var layers: Array = []
	for name in LAYER_ORDER:
		if not rot["layers"].has(name):
			continue
		var layer_path := "%s/%s/%s" % [DIR, prop_id, rot["layers"][name]]
		# Generated props may be present before Godot has created their .import data.
		# Treat that as a missing layer and let the caller keep its fallback drawing,
		# instead of emitting a loader error during unrelated UI/portrait tests.
		if not ResourceLoader.exists(layer_path, "Texture2D"):
			return {}
		var tex := load(layer_path) as Texture2D
		if tex == null:
			return {}
		layers.append(tex)
	if layers.is_empty():
		return {}
	var canvas: Array = rot.get("canvas_px", [320, 320])
	var anchor: Array = rot["anchor_px"]
	return {
		"layers": layers,
		"anchor": Vector2(anchor[0], anchor[1]),
		"size": Vector2(canvas[0], canvas[1]),
	}
