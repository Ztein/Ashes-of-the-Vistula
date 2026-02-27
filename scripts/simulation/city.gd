class_name City
extends RefCounted
## City simulation data. Represents a city on the map with production,
## structure HP, ownership, and tier-based properties.
## All values loaded from balance.json — nothing hardcoded.

var id: int = 0
var city_name: String = ""
var tier: String = ""
var owner_id: int = -1  # -1 = neutral
var structure_hp: float = 0.0
var max_structure_hp: float = 0.0
var local_cap: int = 0
var production_type: String = ""
var production_timer: float = 0.0
var production_interval: float = 0.0
var structure_regen_rate: float = 0.0
var hex_position: Vector2i = Vector2i.ZERO

# Command bonuses (loaded from config)
var _order_cap_bonus: int = 0
var _order_regen_bonus: float = 0.0


func init_from_config(city_data: Dictionary, balance: Dictionary) -> void:
	id = city_data.get("id", 0) as int
	city_name = city_data.get("name", "") as String
	tier = city_data.get("tier", "hamlet") as String
	production_type = city_data.get("production_type", "infantry") as String

	var pos: Array = city_data.get("hex_position", [0, 0])
	hex_position = Vector2i(int(pos[0]), int(pos[1]))

	# Load tier-specific values from balance
	var city_config: Dictionary = balance.get("cities", {}).get(tier, {})
	max_structure_hp = float(city_config.get("structure_hp", 100))
	structure_hp = max_structure_hp
	local_cap = int(city_config.get("local_cap", 5))
	production_interval = float(city_config.get("production_interval", 8.0))
	structure_regen_rate = float(city_config.get("structure_regen_rate", 2.0))

	# Command bonuses only for major cities
	var command_config: Dictionary = balance.get("command", {})
	if tier == "major_city":
		_order_cap_bonus = int(command_config.get("major_city_cap_bonus", 0))
		_order_regen_bonus = float(command_config.get("major_city_regen_bonus", 0.0))
	else:
		_order_cap_bonus = 0
		_order_regen_bonus = 0.0

	production_timer = 0.0


func take_siege_damage(amount: float) -> void:
	structure_hp = maxf(structure_hp - amount, 0.0)


func regenerate_structure(delta: float) -> void:
	structure_hp = minf(structure_hp + structure_regen_rate * delta, max_structure_hp)


func is_structure_destroyed() -> bool:
	return structure_hp <= 0.0


func reset_structure_hp() -> void:
	structure_hp = max_structure_hp


func tick_production(delta: float, current_local_units: int, global_supply_available: bool) -> String:
	# Don't produce if at local cap or global supply is capped
	if current_local_units >= local_cap:
		return ""
	if not global_supply_available:
		return ""
	# Don't produce if neutral
	if owner_id < 0:
		return ""

	production_timer += delta
	if production_timer >= production_interval:
		production_timer -= production_interval
		return production_type

	return ""


func capture(new_owner_id: int) -> void:
	owner_id = new_owner_id
	reset_structure_hp()
	production_timer = 0.0


func get_order_cap_bonus() -> int:
	return _order_cap_bonus


func get_order_regen_bonus() -> float:
	return _order_regen_bonus
