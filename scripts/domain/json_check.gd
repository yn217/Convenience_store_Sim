class_name JsonCheck
extends RefCounted
## Shared JSON field checks. Money/quantity fields must be whole numbers: JSON has
## no int type, so a float is accepted only when it holds an exact integer value.

static func is_int(v) -> bool:
	match typeof(v):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(v) and v == floorf(v) and absf(v) < 9007199254740992.0
		_:
			return false


static func is_number(v) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v))


static func is_id(v) -> bool:
	if typeof(v) != TYPE_STRING:
		return false
	var re := RegEx.new()
	re.compile("^[a-z][a-z0-9_]*$")
	return re.search(v) != null


static func is_nonempty_string(v) -> bool:
	return typeof(v) == TYPE_STRING and not String(v).is_empty()


## Required/unknown key errors for an object (schema: additionalProperties=false).
static func key_errors(obj: Dictionary, required: Array, optional: Array, path: String) -> Array[String]:
	var errs: Array[String] = []
	for k in required:
		if not obj.has(k):
			errs.append("%s.%s: missing_field" % [path, k])
	for k in obj.keys():
		if not required.has(k) and not optional.has(k):
			errs.append("%s.%s: unknown_field" % [path, k])
	return errs
