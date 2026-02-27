class_name BaseTest
extends RefCounted
## Base class for all test scripts. Provides assertion helpers.

var _failure: String = ""


func _get_failure() -> String:
	return _failure


func _clear_failure() -> void:
	_failure = ""


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		var msg := "Expected %s but got %s" % [str(expected), str(actual)]
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		var msg := "Expected values to differ but both are %s" % str(actual)
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_true(value: bool, message: String = "") -> void:
	if not value:
		var msg := "Expected true but got false"
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_false(value: bool, message: String = "") -> void:
	if value:
		var msg := "Expected false but got true"
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		var msg := "Expected null but got %s" % str(value)
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		var msg := "Expected non-null value but got null"
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_gt(actual: float, threshold: float, message: String = "") -> void:
	if actual <= threshold:
		var msg := "Expected %s > %s" % [str(actual), str(threshold)]
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_lt(actual: float, threshold: float, message: String = "") -> void:
	if actual >= threshold:
		var msg := "Expected %s < %s" % [str(actual), str(threshold)]
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_gte(actual: float, threshold: float, message: String = "") -> void:
	if actual < threshold:
		var msg := "Expected %s >= %s" % [str(actual), str(threshold)]
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_lte(actual: float, threshold: float, message: String = "") -> void:
	if actual > threshold:
		var msg := "Expected %s <= %s" % [str(actual), str(threshold)]
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_approx(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		var msg := "Expected ~%s but got %s (tolerance: %s)" % [str(expected), str(actual), str(tolerance)]
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_empty(collection: Variant, message: String = "") -> void:
	var is_empty := false
	if collection is Array:
		is_empty = (collection as Array).is_empty()
	elif collection is Dictionary:
		is_empty = (collection as Dictionary).is_empty()
	elif collection is String:
		is_empty = (collection as String).is_empty()
	else:
		_failure = "assert_empty: unsupported type"
		return

	if not is_empty:
		var msg := "Expected empty collection but got %s" % str(collection)
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg


func assert_not_empty(collection: Variant, message: String = "") -> void:
	var is_empty := true
	if collection is Array:
		is_empty = (collection as Array).is_empty()
	elif collection is Dictionary:
		is_empty = (collection as Dictionary).is_empty()
	elif collection is String:
		is_empty = (collection as String).is_empty()
	else:
		_failure = "assert_not_empty: unsupported type"
		return

	if is_empty:
		var msg := "Expected non-empty collection"
		if not message.is_empty():
			msg = "%s — %s" % [message, msg]
		_failure = msg
