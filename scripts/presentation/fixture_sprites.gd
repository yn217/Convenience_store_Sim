class_name FixtureSprites
extends RefCounted
## Manifest-driven fixture sprites (#9). Loads assets/generated/fixtures/<type>/<type>_a.visual.json
## and the imported layer textures once; types without a manifest return {} (placeholder boxes).

const DIR := "res://assets/generated/fixtures"
const LAYER_ORDER_BELOW := ["shadow", "body"]
const LAYER_ORDER_ABOVE := ["glass_front"]

var _cache: Dictionary = {}


## {"anchor": Vector2, "layers": {name: Texture2D}, "slots": {slot_name: Vector2}} or {}.
func rotation_entry(type_id: String, rotation: int) -> Dictionary:
	var key := "%s/%d" % [type_id, rotation]
	if _cache.has(key):
		return _cache[key]
	var entry := _load(type_id, rotation)
	_cache[key] = entry
	return entry


func has_sprites(type_id: String) -> bool:
	return FileAccess.file_exists("%s/%s/%s_a.visual.json" % [DIR, type_id, type_id])


func _load(type_id: String, rotation: int) -> Dictionary:
	var path := "%s/%s/%s_a.visual.json" % [DIR, type_id, type_id]
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var rot: Dictionary = json.data["rotations"].get(str(rotation), {})
	if rot.is_empty():
		return {}
	var layers := {}
	for name in rot["layers"]:
		var tex := load("%s/%s/%s" % [DIR, type_id, rot["layers"][name]]) as Texture2D
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
	}
