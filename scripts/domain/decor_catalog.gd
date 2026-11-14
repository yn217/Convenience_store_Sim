class_name DecorCatalog
extends RefCounted
## Storefront decorations (data/decor/decor_v1.json, user's decision 2026-11-14): bought once per store, drawn outside
## it by StoreDecor. Looks only: nothing in the simulation reads them (the user chose no effect on sales).

const DATA_PATH := "res://data/decor/decor_v1.json"
const FROM := ["door_left", "door_right", "start", "end"]

static var _items: Array = []


static func items() -> Array:
	if _items.is_empty():
		var errors: Array[String] = []
		_items = parse(JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)), errors)
		if not errors.is_empty():
			push_error("decor: %s" % str(errors))
	return _items


static func find(decor_id: String) -> Dictionary:
	for d in items():
		if String(d["decor_id"]) == decor_id:
			return d
	return {}


## The valid items of a file; a bad one is left out with its reason in `errors`.
static func parse(data, errors: Array[String] = []) -> Array:
	var out: Array = []
	var rows = data.get("decor", null) if typeof(data) == TYPE_DICTIONARY else null
	if typeof(rows) != TYPE_ARRAY:
		errors.append("decor: missing")
		return out
	var seen := {}
	for i in rows.size():
		var r = rows[i]
		var before := errors.size()
		if typeof(r) != TYPE_DICTIONARY:
			errors.append("decor[%d]: not an object" % i)
			continue
		var id := String(r.get("decor_id", ""))
		if id == "" or seen.has(id):
			errors.append("decor[%d]: decor_id missing or repeated" % i)
		seen[id] = true
		for k in ["name_ja", "description_ja", "prop_id"]:
			if not JsonCheck.is_nonempty_string(r.get(k)):
				errors.append("decor[%d]: %s missing" % [i, k])
		if not JsonCheck.is_int(r.get("price_yen")) or int(r["price_yen"]) < 0:
			errors.append("decor[%d]: price_yen invalid" % i)
		var spots = r.get("spots", [])
		if typeof(spots) != TYPE_ARRAY or spots.is_empty():
			errors.append("decor[%d]: spots missing" % i)
			spots = []
		for s in spots:
			if typeof(s) != TYPE_DICTIONARY or not FROM.has(String(s.get("from", ""))) or not JsonCheck.is_number(s.get("along")) or not JsonCheck.is_number(s.get("depth")):
				errors.append("decor[%d]: spot %s invalid" % [i, str(s)])
		if errors.size() > before:
			continue
		out.append({"decor_id": id, "name_ja": String(r["name_ja"]), "description_ja": String(r["description_ja"]), "prop_id": String(r["prop_id"]),
			"price_yen": int(r["price_yen"]), "spots": (spots as Array).duplicate(true)})
	return out
