class_name ConfigLoader
extends RefCounted
## Utility for loading and validating JSON configuration files.


const REQUIRED_BALANCE_KEYS: Array[String] = [
	"units", "cities", "supply", "command", "dominance", "simulation"
]

const REQUIRED_UNIT_KEYS: Array[String] = [
	"hp", "dps", "siege_damage", "speed", "production_time"
]

const REQUIRED_CITY_KEYS: Array[String] = [
	"local_cap", "structure_hp", "production_interval", "structure_regen_rate"
]


func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("ConfigLoader: file not found: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ConfigLoader: cannot open file: %s" % path)
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("ConfigLoader: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return null

	return json.data


func load_balance(path: String = "res://data/balance.json") -> Dictionary:
	var data: Variant = load_json(path)
	if data == null or not data is Dictionary:
		push_error("ConfigLoader: balance data is not a Dictionary")
		return {}

	var dict: Dictionary = data
	for key in REQUIRED_BALANCE_KEYS:
		if not dict.has(key):
			push_error("ConfigLoader: balance.json missing required key: %s" % key)
			return {}

	return dict


func load_map(path: String = "res://data/map.json") -> Dictionary:
	var data: Variant = load_json(path)
	if data == null or not data is Dictionary:
		push_error("ConfigLoader: map data is not a Dictionary")
		return {}

	var dict: Dictionary = data
	if not dict.has("cities") or not dict.has("adjacency"):
		push_error("ConfigLoader: map.json missing 'cities' or 'adjacency'")
		return {}

	return dict


func load_scenario(path: String = "res://data/scenario.json") -> Dictionary:
	var data: Variant = load_json(path)
	if data == null or not data is Dictionary:
		push_error("ConfigLoader: scenario data is not a Dictionary")
		return {}

	var dict: Dictionary = data
	if not dict.has("players") or not dict.has("city_ownership"):
		push_error("ConfigLoader: scenario.json missing 'players' or 'city_ownership'")
		return {}

	return dict
