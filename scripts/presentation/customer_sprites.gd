class_name CustomerSprites
extends RefCounted
## Manifest-driven customer sprites (#23). Three variants x 4 facings x walk 6 / idle 2 / inspect 4
## frames, all cropped to one canvas and one anchor (the feet), so facing or frame changes never
## move the ground contact. Missing art returns {} and the caller draws a plain placeholder.

const DIR := "res://assets/generated/characters"
const VARIANTS: Array[String] = ["customer_a", "customer_b", "customer_c"]
## Facing index = clockwise quarter turns from +x (E, S, W, N), as in the manifests.
const FACING_E := 0
const FACING_S := 1
const FACING_W := 2
const FACING_N := 3

var _cache: Dictionary = {}


## {"anchor": Vector2, "canvas": Vector2, "shadow": Texture2D, "animations": {name: {frames, fps, loop}},
##  "frames": {facing: {anim: [Texture2D]}}} or {}.
func variant(variant_id: String) -> Dictionary:
	if not _cache.has(variant_id):
		_cache[variant_id] = _load(variant_id)
	return _cache[variant_id]


## Stable variant for a customer id: the numeric tail picks one of the three looks.
static func variant_for(customer_id: String) -> String:
	var digits := ""
	for i in range(customer_id.length() - 1, -1, -1):
		var ch := customer_id[i]
		if ch < "0" or ch > "9":
			break
		digits = ch + digits
	return VARIANTS[(digits.to_int() if digits != "" else customer_id.hash()) % VARIANTS.size()]


## Facing for a movement vector in tile units (dominant axis); `keep` when there is no movement.
static func facing_for(delta: Vector2, keep: int) -> int:
	if delta.length() < 0.001:
		return keep
	if absf(delta.x) >= absf(delta.y):
		return FACING_E if delta.x > 0.0 else FACING_W
	return FACING_S if delta.y > 0.0 else FACING_N


## Animation for the customer's phase (14 §2): walking, standing in line, reaching for a shelf.
static func anim_for(phase: String) -> String:
	match phase:
		"WALK_SHELF", "WALK_REGISTER", "EXIT":
			return "walk"
		"SELECT":
			return "inspect"
	return "idle"


## Frame index for animation time in game seconds (never wall time: speed 0 freezes it).
static func frame_index(spec: Dictionary, anim_time: float) -> int:
	var n := int(spec["frames"])
	var k := int(floor(anim_time * float(spec["fps"])))
	if bool(spec["loop"]):
		return posmod(k, n)
	return clampi(k, 0, n - 1)


func _load(variant_id: String) -> Dictionary:
	var path := "%s/%s/%s.character.json" % [DIR, variant_id, variant_id]
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	var m: Dictionary = json.data
	var shadow := load("%s/%s/%s" % [DIR, variant_id, m["shadow"]]) as Texture2D
	if shadow == null:
		return {}
	var frames := {}
	for d in m["directions"]:
		frames[int(d)] = {}
		for anim in m["directions"][d]:
			var list: Array[Texture2D] = []
			for rel in m["directions"][d][anim]:
				var tex := load("%s/%s/%s" % [DIR, variant_id, rel]) as Texture2D
				if tex == null:
					return {}
				list.append(tex)
			frames[int(d)][anim] = list
	return {
		"anchor": Vector2(m["anchor_px"][0], m["anchor_px"][1]),
		"canvas": Vector2(m["canvas_px"][0], m["canvas_px"][1]),
		"height_m": float(m["height_m"]),
		"shadow": shadow,
		"animations": m["animations"],
		"frames": frames,
	}
