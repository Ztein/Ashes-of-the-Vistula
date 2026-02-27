extends BaseTest
## Integration test that validates ALL .gd scripts and .tscn scenes.
##
## Runs validate_scripts.gd as a subprocess using OS.execute() and checks
## both the exit code AND stderr for parse errors. This catches errors that
## load() misses (it can return non-null for broken scripts), because Godot
## reliably logs parse errors to stderr.
##
## This test would have caught the type inference error in game.gd that
## slipped through simulation-only tests.

## Error patterns that indicate a real script/scene problem.
## These appear in Godot's stderr even when load() returns non-null.
const ERROR_PATTERNS: Array[String] = [
	"Parse Error",
	"SCRIPT ERROR",
	"ERROR: Failed to load script",
	"ERROR: Failed to load resource",
]

## Path to the Godot binary.
const GODOT_PATH := "/opt/homebrew/bin/godot"

## Cached result from the subprocess validator run.
var _cached_result: Dictionary = {}


# --- Helpers ---

func _get_validator_result() -> Dictionary:
	## Runs validate_scripts.gd in a fresh Godot process (cached).
	## Returns {"exit_code": int, "output": String, "error_lines": PackedStringArray}
	if not _cached_result.is_empty():
		return _cached_result

	var output: Array = []
	var project_path := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute(GODOT_PATH, [
		"--path", project_path,
		"--headless",
		"-s", "tests/validate_scripts.gd"
	], output, true)  # true = read_stderr — merges stderr into output

	# OS.execute() puts the entire output as one string in the array.
	# Split into individual lines for pattern matching.
	var full_output := "\n".join(output)
	var lines := full_output.split("\n")

	# Collect lines matching error patterns
	var error_lines: PackedStringArray = []
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue
		for pattern in ERROR_PATTERNS:
			if pattern in stripped:
				error_lines.append(stripped)
				break

	_cached_result = {
		"exit_code": exit_code,
		"output": full_output,
		"error_lines": error_lines,
	}
	return _cached_result


# --- Tests ---

func test_all_scripts_parse_without_errors() -> void:
	## Runs the standalone validator and checks for parse errors in stderr.
	## This is the primary test that catches ALL types of GDScript errors
	## (type inference, missing identifiers, syntax errors) across all scripts.
	var result := _get_validator_result()
	var error_lines: PackedStringArray = result["error_lines"]

	if not error_lines.is_empty():
		# Show only the most relevant error lines (SCRIPT ERROR and Parse Error)
		var summary: PackedStringArray = []
		for line in error_lines:
			if "SCRIPT ERROR" in line or "Parse Error" in line:
				summary.append(line)
		if summary.is_empty():
			summary = error_lines
		var msg := "Script validation errors:\n"
		for line in summary:
			msg += "  %s\n" % line
		assert_true(false, msg)
	else:
		assert_true(true, "All scripts parsed without errors")


func test_validator_exit_code_is_zero() -> void:
	## The validator itself should exit with code 0 when all scripts are valid.
	var result := _get_validator_result()
	assert_eq(result["exit_code"], 0, "Validator should exit with code 0")


func test_validator_reports_validation_passed() -> void:
	## The validator should print "VALIDATION PASSED" on success.
	var result := _get_validator_result()
	var output: String = result["output"]
	assert_true("VALIDATION PASSED" in output, "Validator should report VALIDATION PASSED")


func test_game_scene_loads() -> void:
	## Verifies that game.tscn can be loaded within the test runner process.
	var scene: PackedScene = load("res://scenes/game/game.tscn") as PackedScene
	assert_not_null(scene, "game.tscn should load without errors")


func test_main_scene_loads() -> void:
	## Verifies that main.tscn can be loaded within the test runner process.
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	assert_not_null(scene, "main.tscn should load without errors")
