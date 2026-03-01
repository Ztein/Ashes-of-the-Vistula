class_name UnitStack
extends RefCounted
## A homogeneous stack of units at a city or moving between cities.
## Each stack contains exactly one unit type (infantry, cavalry, or artillery).
## All stat calculations use balance config, nothing hardcoded.

var id: int = 0
var owner_id: int = 0
var city_id: int = 0

var unit_type: String = ""  # "infantry", "cavalry", or "artillery"
var count: int = 0
var hp_pool: float = 0.0

var is_moving: bool = false
var move_target_city_id: int = -1
var move_progress: float = 0.0


func init_hp_pools(balance: Dictionary) -> void:
	var units_config: Dictionary = balance.get("units", {})
	var hp_each: float = float(units_config.get(unit_type, {}).get("hp", 100))
	hp_pool = count * hp_each


func get_total_hp() -> float:
	return hp_pool


func apply_damage(damage: float, balance: Dictionary) -> void:
	## Applies damage to this stack's HP pool, removing units as HP depletes.
	if damage <= 0.0 or hp_pool <= 0.0:
		return
	hp_pool -= damage
	if hp_pool <= 0.0:
		hp_pool = 0.0
		count = 0
	else:
		var units_config: Dictionary = balance.get("units", {})
		var hp_each: float = float(units_config.get(unit_type, {}).get("hp", 100))
		if hp_each > 0:
			count = ceili(hp_pool / hp_each)


func total_units() -> int:
	return count


func total_dps(balance: Dictionary) -> float:
	var units_config: Dictionary = balance.get("units", {})
	var hp_each: float = float(units_config.get(unit_type, {}).get("hp", 100))
	var dps: float = float(units_config.get(unit_type, {}).get("dps", 0))
	if hp_each <= 0.0:
		return 0.0
	return (hp_pool / hp_each) * dps


func total_siege_damage(balance: Dictionary) -> float:
	var units_config: Dictionary = balance.get("units", {})
	var hp_each: float = float(units_config.get(unit_type, {}).get("hp", 100))
	var siege: float = float(units_config.get(unit_type, {}).get("siege_damage", 0))
	if hp_each <= 0.0:
		return 0.0
	return (hp_pool / hp_each) * siege


func movement_speed(balance: Dictionary) -> float:
	if count <= 0:
		return 0.0
	var units_config: Dictionary = balance.get("units", {})
	return float(units_config.get(unit_type, {}).get("speed", 1.0))


func split_half() -> UnitStack:
	## Halves this stack. Returns a new stack with floor(count/2) units.
	## This stack keeps ceil(count/2). Returns null if count <= 1.
	if count <= 1:
		return null

	var split_count: int = count / 2  # floor division
	count -= split_count

	# Split HP proportionally
	var total_hp_before: float = hp_pool
	var ratio: float = float(split_count) / float(split_count + count)
	var split_hp: float = total_hp_before * ratio
	hp_pool -= split_hp

	var new_stack := UnitStack.new()
	new_stack.owner_id = owner_id
	new_stack.city_id = city_id
	new_stack.unit_type = unit_type
	new_stack.count = split_count
	new_stack.hp_pool = split_hp
	return new_stack


func merge(other: UnitStack) -> bool:
	if other.owner_id != owner_id:
		return false
	if other.city_id != city_id:
		return false
	if other.unit_type != unit_type:
		return false

	count += other.count
	hp_pool += other.hp_pool
	return true


func start_move(target_city_id: int) -> void:
	is_moving = true
	move_target_city_id = target_city_id
	move_progress = 0.0


func tick_move(delta: float, speed: float) -> bool:
	if not is_moving:
		return false

	move_progress += delta * speed
	if move_progress >= 1.0:
		city_id = move_target_city_id
		is_moving = false
		move_target_city_id = -1
		move_progress = 0.0
		return true

	return false


func is_empty() -> bool:
	return count == 0 or hp_pool <= 0.0
