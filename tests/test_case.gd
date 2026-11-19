extends RefCounted
## Minimal assertion base for the headless test runner (see run_tests.gd).

var failures: Array[String] = []
var _current := ""

func run_all() -> int:
	var count := 0
	for method in get_method_list():
		var method_name: String = method.name
		if not method_name.begins_with("test_"):
			continue
		_current = method_name
		call(method_name)
		count += 1
	return count

func check(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append("%s: %s" % [_current, message if message else "check failed"])

func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		if is_equal_approx(float(actual), float(expected)):
			return
	elif actual == expected:
		return
	failures.append("%s: %s expected %s, got %s" % [_current, message, str(expected), str(actual)])
