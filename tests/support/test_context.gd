extends RefCounted
## Minimal assertion collector passed to every test_* method as `t`.

var failures: Array[String] = []
var assertions: int = 0
var current: String = ""


func eq(actual, expected, label: String = "") -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s %s: expected %s (%s), got %s (%s)" % [
			current, label, str(expected), type_string(typeof(expected)),
			str(actual), type_string(typeof(actual))])


func ok(condition: bool, label: String = "") -> void:
	assertions += 1
	if not condition:
		failures.append("%s %s: condition false" % [current, label])
