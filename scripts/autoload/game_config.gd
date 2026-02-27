extends Node
## Autoloaded singleton providing access to game configuration data.
## Loads balance.json on startup and exposes typed getters.

signal config_reloaded

var _balance: Dictionary = {}
var _loader: ConfigLoader = ConfigLoader.new()


func _ready() -> void:
	reload_balance()


func reload_balance() -> void:
	_balance = _loader.load_balance()
	if _balance.is_empty():
		push_error("GameConfig: failed to load balance data")
	else:
		config_reloaded.emit()


func get_balance() -> Dictionary:
	return _balance


func get_unit_config(unit_type: String) -> Dictionary:
	if _balance.has("units") and _balance["units"].has(unit_type):
		return _balance["units"][unit_type]
	push_error("GameConfig: unknown unit type: %s" % unit_type)
	return {}


func get_city_config(tier: String) -> Dictionary:
	if _balance.has("cities") and _balance["cities"].has(tier):
		return _balance["cities"][tier]
	push_error("GameConfig: unknown city tier: %s" % tier)
	return {}


func get_supply_config() -> Dictionary:
	return _balance.get("supply", {})


func get_command_config() -> Dictionary:
	return _balance.get("command", {})


func get_dominance_config() -> Dictionary:
	return _balance.get("dominance", {})


func get_simulation_config() -> Dictionary:
	return _balance.get("simulation", {})


func get_ai_config() -> Dictionary:
	return _balance.get("ai", {})
