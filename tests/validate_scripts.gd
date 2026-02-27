extends SceneTree
## Standalone script & scene validator.
## Run in a FRESH Godot process to bypass cache:
##   godot --path . --headless -s tests/validate_scripts.gd
##
## Exit code: 0 = all valid, 1 = errors found.
##
## Validation runs after the first process frame so that autoload singletons
## (e.g. GameConfig) are registered and available for compilation.
##
## IMPORTANT: Godot's load() may return non-null even for broken scripts,
## but parse errors are reliably printed to stderr. The integration test
## (test_script_validation.gd) runs this as a subprocess and checks stderr.

const SCRIPT_DIRS: Array[String] = [
	"res://scripts/simulation/",
	"res://scripts/autoload/",
	"res://scripts/ai/",
	"res://scenes/game/",
	"res://scenes/map/",
	"res://scenes/ui/",
	"res://scenes/",
]

const SCENE_PATHS: Array[String] = [
	"res://scenes/main.tscn",
	"res://scenes/game/game.tscn",
	"res://scenes/ui/admin_panel.tscn",
]

var _errors: int = 0
var _checked: int = 0
var _done := false


func _init() -> void:
	# Defer validation so autoloads are fully set up first.
	pass


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	print("\n--- Script & Scene Validation ---\n")

	_validate_scripts()
	_validate_scenes()

	print("\nChecked %d items, %d error(s)." % [_checked, _errors])

	if _errors == 0:
		print("VALIDATION PASSED")
		quit(0)
	else:
		print("VALIDATION FAILED")
		quit(1)
	return true


func _validate_scripts() -> void:
	print("[Scripts]")
	for dir_path in SCRIPT_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".gd"):
				var path := dir_path + file_name
				_checked += 1
				var script = load(path)
				if script == null:
					print("  FAIL: %s" % path)
					_errors += 1
				else:
					print("  OK: %s" % path)
			file_name = dir.get_next()
		dir.list_dir_end()


func _validate_scenes() -> void:
	print("\n[Scenes]")
	for path in SCENE_PATHS:
		_checked += 1
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			print("  FAIL: %s" % path)
			_errors += 1
		else:
			print("  OK: %s" % path)
			# Also try instantiation
			_checked += 1
			var instance: Node = scene.instantiate()
			if instance == null:
				print("  FAIL (instantiate): %s" % path)
				_errors += 1
			else:
				print("  OK (instantiate): %s" % path)
				instance.free()
