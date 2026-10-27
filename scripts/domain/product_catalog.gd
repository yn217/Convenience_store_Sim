class_name ProductCatalog
extends RefCounted
## ProductSKU master (product_definition.schema.json + semantic checks).
## Master data only: price overrides and stock live elsewhere (Inventory / GameState).

const SUPPORTED_SCHEMA_VERSION := 1
const CATEGORIES: Array[String] = [
	"rice_ball", "oden", "instant_noodle", "bread", "drink", "snack", "dessert", "ice_cream",
	"bento", "daily_fresh", "coffee",   # #147: lunch boxes, vegetables / dairy, counter coffee
	"capsule_toy",   # #139: capsule toy machines
	"daily_goods", "hygiene",   # #133: socks, underwear, umbrellas / masks, plasters, wet wipes (no medicines)
	"soft_serve", "frappe",   # #131: made to order at their machines
	"bakery", "pizza",   # #130: fresh bread from the store's oven, pizza baked to order
]
const REQUIRED := [
	"schema_version", "sku_id", "display_name", "category", "purchase_cost_yen",
	"default_sell_price_yen", "expires_after_seconds", "demand_weight", "visual_id", "slot_units",
]

var skus: Dictionary = {}
var errors: Array[String] = []
## True when some entry declares a schema_version newer than this build understands.
var future_schema_version: bool = false


static func from_json_text(text: String) -> ProductCatalog:
	var cat := ProductCatalog.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		cat.errors.append("$: invalid_json")
		return cat
	return from_array(json.data)


static func from_array(data) -> ProductCatalog:
	var cat := ProductCatalog.new()
	if typeof(data) != TYPE_ARRAY:
		cat.errors.append("$: root_not_array")
		return cat
	for i in data.size():
		cat._add_entry(data[i], "$[%d]" % i)
	return cat


func is_valid() -> bool:
	return errors.is_empty()


func has_sku(sku_id: String) -> bool:
	return skus.has(sku_id)


func get_sku(sku_id: String) -> Dictionary:
	return skus.get(sku_id, {})


func _add_entry(e, path: String) -> void:
	if typeof(e) != TYPE_DICTIONARY:
		errors.append("%s: not_object" % path)
		return
	var errs := JsonCheck.key_errors(e, REQUIRED, [], path)
	if e.has("schema_version"):
		if not JsonCheck.is_int(e["schema_version"]):
			errs.append("%s.schema_version: not_integer" % path)
		elif int(e["schema_version"]) > SUPPORTED_SCHEMA_VERSION:
			future_schema_version = true
			errs.append("%s.schema_version: unsupported_schema_version" % path)
		elif int(e["schema_version"]) != SUPPORTED_SCHEMA_VERSION:
			errs.append("%s.schema_version: invalid_schema_version" % path)
	if e.has("sku_id") and not JsonCheck.is_id(e["sku_id"]):
		errs.append("%s.sku_id: invalid_id" % path)
	if e.has("display_name") and not JsonCheck.is_nonempty_string(e["display_name"]):
		errs.append("%s.display_name: empty" % path)
	if e.has("category") and not CATEGORIES.has(e["category"]):
		errs.append("%s.category: unknown_category" % path)
	if e.has("purchase_cost_yen"):
		if not JsonCheck.is_int(e["purchase_cost_yen"]):
			errs.append("%s.purchase_cost_yen: not_integer" % path)
		elif int(e["purchase_cost_yen"]) < 0:
			errs.append("%s.purchase_cost_yen: negative" % path)
	if e.has("default_sell_price_yen"):
		if not JsonCheck.is_int(e["default_sell_price_yen"]):
			errs.append("%s.default_sell_price_yen: not_integer" % path)
		elif int(e["default_sell_price_yen"]) < 1:
			errs.append("%s.default_sell_price_yen: below_minimum" % path)
	if e.has("expires_after_seconds") and e["expires_after_seconds"] != null:
		if not JsonCheck.is_int(e["expires_after_seconds"]):
			errs.append("%s.expires_after_seconds: not_integer" % path)
		elif int(e["expires_after_seconds"]) < 1:
			errs.append("%s.expires_after_seconds: below_minimum" % path)
	if e.has("demand_weight"):
		if not JsonCheck.is_number(e["demand_weight"]):
			errs.append("%s.demand_weight: not_number" % path)
		elif float(e["demand_weight"]) < 0.0:
			errs.append("%s.demand_weight: negative" % path)
	if e.has("visual_id") and not JsonCheck.is_id(e["visual_id"]):
		errs.append("%s.visual_id: invalid_id" % path)
	if e.has("slot_units"):
		if not JsonCheck.is_int(e["slot_units"]):
			errs.append("%s.slot_units: not_integer" % path)
		elif int(e["slot_units"]) < 1:
			errs.append("%s.slot_units: below_minimum" % path)
	if errs.is_empty() and skus.has(e["sku_id"]):
		errs.append("%s.sku_id: duplicate_id" % path)
	errors.append_array(errs)
	if errs.is_empty():
		var n: Dictionary = e.duplicate()
		for k in ["schema_version", "purchase_cost_yen", "default_sell_price_yen", "slot_units"]:
			n[k] = int(n[k])
		if n["expires_after_seconds"] != null:
			n["expires_after_seconds"] = int(n["expires_after_seconds"])
		skus[n["sku_id"]] = n
