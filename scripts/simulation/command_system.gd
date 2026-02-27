class_name CommandSystem
extends RefCounted
## Per-player order pool with cap and regeneration.
## Major cities boost both cap and regen rate. All values from config.

# player_id -> { current_orders: float, order_cap: int, regen_rate: float }
var _player_data: Dictionary = {}


func initialize_player(player_id: int, owned_cities: Array, balance: Dictionary) -> void:
	var cap := _calculate_order_cap(owned_cities, balance)
	var regen := _calculate_regen_rate(owned_cities, balance)
	_player_data[player_id] = {
		"current_orders": float(cap),  # Start at cap
		"order_cap": cap,
		"regen_rate": regen,
	}


func tick_regeneration(player_id: int, delta: float) -> void:
	if not _player_data.has(player_id):
		return
	var data: Dictionary = _player_data[player_id]
	data["current_orders"] = minf(
		float(data["current_orders"]) + float(data["regen_rate"]) * delta,
		float(data["order_cap"])
	)


func spend_order(player_id: int, cost: int) -> bool:
	if not can_afford(player_id, cost):
		return false
	var data: Dictionary = _player_data[player_id]
	data["current_orders"] = float(data["current_orders"]) - float(cost)
	return true


func can_afford(player_id: int, cost: int) -> bool:
	if not _player_data.has(player_id):
		return false
	return float(_player_data[player_id]["current_orders"]) >= float(cost)


func get_command_info(player_id: int) -> Dictionary:
	if not _player_data.has(player_id):
		return {"current_orders": 0.0, "order_cap": 0, "regen_rate": 0.0}
	var data: Dictionary = _player_data[player_id]
	return {
		"current_orders": float(data["current_orders"]),
		"order_cap": int(data["order_cap"]),
		"regen_rate": float(data["regen_rate"]),
	}


func recalculate(player_id: int, owned_cities: Array, balance: Dictionary) -> void:
	if not _player_data.has(player_id):
		initialize_player(player_id, owned_cities, balance)
		return

	var new_cap := _calculate_order_cap(owned_cities, balance)
	var new_regen := _calculate_regen_rate(owned_cities, balance)

	var data: Dictionary = _player_data[player_id]
	data["order_cap"] = new_cap
	data["regen_rate"] = new_regen
	# Clamp current orders to new cap
	data["current_orders"] = minf(float(data["current_orders"]), float(new_cap))


func _calculate_order_cap(owned_cities: Array, balance: Dictionary) -> int:
	var command_config: Dictionary = balance.get("command", {})
	var base_cap: int = int(command_config.get("base_order_cap", 3))
	var major_bonus: int = int(command_config.get("major_city_cap_bonus", 1))

	var total := base_cap
	for city_obj in owned_cities:
		var city: City = city_obj as City
		if city.tier == "major_city":
			total += major_bonus

	return total


func _calculate_regen_rate(owned_cities: Array, balance: Dictionary) -> float:
	var command_config: Dictionary = balance.get("command", {})
	var base_regen: float = float(command_config.get("base_regen_rate", 0.1))
	var major_bonus: float = float(command_config.get("major_city_regen_bonus", 0.05))

	var total := base_regen
	for city_obj in owned_cities:
		var city: City = city_obj as City
		if city.tier == "major_city":
			total += major_bonus

	return total
