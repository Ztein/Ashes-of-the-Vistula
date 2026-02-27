extends SceneTree
## Headless test runner for Ashes of the Vistula.
## Usage:
##   godot --path . --headless -s tests/test_runner.gd
##   godot --path . --headless -s tests/test_runner.gd -- --unit
##   godot --path . --headless -s tests/test_runner.gd -- --integration
##   godot --path . --headless -s tests/test_runner.gd -- --file=test_combat_resolver.gd

const UNIT_TEST_DIR := "res://tests/unit/"
const INTEGRATION_TEST_DIR := "res://tests/integration/"

var _pass_count: int = 0
var _fail_count: int = 0
var _errors: Array[String] = []


func _init() -> void:
	var args := _parse_args()
	var run_unit := args.get("unit", true) as bool
	var run_integration := args.get("integration", true) as bool
	var file_filter := args.get("file", "") as String

	print("\n========================================")
	print("  Ashes of the Vistula — Test Runner")
	print("========================================\n")

	if run_unit:
		_run_tests_in_dir(UNIT_TEST_DIR, file_filter)
	if run_integration:
		_run_tests_in_dir(INTEGRATION_TEST_DIR, file_filter)

	_print_results()

	if _fail_count > 0:
		quit(1)
	else:
		quit(0)


func _parse_args() -> Dictionary:
	var result := {
		"unit": true,
		"integration": true,
		"file": "",
	}

	var args := OS.get_cmdline_user_args()
	for arg in args:
		match arg:
			"--unit":
				result["integration"] = false
			"--integration":
				result["unit"] = false
			_:
				if arg.begins_with("--file="):
					result["file"] = arg.substr(7)
					# When filtering by file, run both dirs to find it
					result["unit"] = true
					result["integration"] = true

	return result


func _run_tests_in_dir(dir_path: String, file_filter: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		print("  [SKIP] Directory not found: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			if file_filter.is_empty() or file_name == file_filter:
				_run_test_file(dir_path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _run_test_file(path: String) -> void:
	print("--- %s ---" % path.get_file())

	var script := load(path) as GDScript
	if script == null:
		print("  [ERROR] Could not load: %s" % path)
		_fail_count += 1
		_errors.append("Could not load: %s" % path)
		return

	var instance: Object = script.new()

	# Call setup if it exists
	if instance.has_method("before_all"):
		instance.call("before_all")

	var methods := script.get_script_method_list()
	for method in methods:
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			_run_single_test(instance, method_name)

	# Call teardown if it exists
	if instance.has_method("after_all"):
		instance.call("after_all")

	print("")


func _run_single_test(instance: Object, method_name: String) -> void:
	# Call per-test setup if it exists
	if instance.has_method("before_each"):
		instance.call("before_each")

	var result := _execute_test(instance, method_name)

	# Call per-test teardown if it exists
	if instance.has_method("after_each"):
		instance.call("after_each")

	if result.is_empty():
		_pass_count += 1
		print("  [PASS] %s" % method_name)
	else:
		_fail_count += 1
		_errors.append("%s: %s" % [method_name, result])
		print("  [FAIL] %s — %s" % [method_name, result])


func _execute_test(instance: Object, method_name: String) -> String:
	# Inject assertion helpers
	if instance.has_method("_set_runner"):
		instance.call("_set_runner", self)

	instance.call(method_name)

	# Check if the test flagged a failure
	if instance.has_method("_get_failure"):
		var failure: String = instance.call("_get_failure")
		if not failure.is_empty():
			# Clear failure for next test
			if instance.has_method("_clear_failure"):
				instance.call("_clear_failure")
			return failure

	return ""


func _print_results() -> void:
	print("========================================")
	print("  Results: %d passed, %d failed" % [_pass_count, _fail_count])
	print("========================================")

	if not _errors.is_empty():
		print("\nFailures:")
		for err in _errors:
			print("  • %s" % err)

	print("")
