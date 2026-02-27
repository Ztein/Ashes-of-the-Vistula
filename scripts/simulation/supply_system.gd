class_name SupplySystem
extends RefCounted
## Calculates global supply cap from base + city bonuses + territory hex bonuses.
## Each unit consumes 1 supply. Production halts when cap reached.


func calculate_supply_cap(player_id: int, owned_cities: Array, territory_hex_count: int, balance: Dictionary) -> int:
	var supply_config: Dictionary = balance.get("supply", {})
	var base_cap: int = int(supply_config.get("base_cap", 20))
	var per_major: int = int(supply_config.get("per_major_city", 5))
	var per_minor: int = int(supply_config.get("per_minor_city", 2))
	var per_hex: float = float(supply_config.get("per_territory_hex", 0.5))

	var total: int = base_cap

	for city_obj in owned_cities:
		var city: City = city_obj as City
		if city.owner_id != player_id:
			continue
		if city.tier == "major_city":
			total += per_major
		else:
			total += per_minor

	total += int(floorf(territory_hex_count * per_hex))

	return total


func calculate_current_supply(player_id: int, stacks: Array) -> int:
	var total: int = 0
	for stack_obj in stacks:
		var stack: UnitStack = stack_obj as UnitStack
		if stack.owner_id == player_id:
			total += stack.total_units()
	return total


func is_at_supply_cap(player_id: int, owned_cities: Array, stacks: Array, territory_hex_count: int, balance: Dictionary) -> bool:
	var cap := calculate_supply_cap(player_id, owned_cities, territory_hex_count, balance)
	var current := calculate_current_supply(player_id, stacks)
	return current >= cap


func get_supply_info(player_id: int, owned_cities: Array, stacks: Array, territory_hex_count: int, balance: Dictionary) -> Dictionary:
	var cap := calculate_supply_cap(player_id, owned_cities, territory_hex_count, balance)
	var current := calculate_current_supply(player_id, stacks)
	return {
		"current": current,
		"cap": cap,
		"available": maxi(cap - current, 0),
	}
