class_name UnitStack
extends RefCounted
## A stack of units at a city or moving between cities.
## Units are tracked as counts per type — no individual unit micro.
## All stat calculations use balance config, nothing hardcoded.

var id: int = 0
var owner_id: int = 0
var city_id: int = 0

var infantry_count: int = 0
var cavalry_count: int = 0
var artillery_count: int = 0

var infantry_hp_pool: float = 0.0
var cavalry_hp_pool: float = 0.0
var artillery_hp_pool: float = 0.0

var is_moving: bool = false
var move_target_city_id: int = -1
var move_progress: float = 0.0


func init_hp_pools(balance: Dictionary) -> void:
	var units_config: Dictionary = balance.get("units", {})
	var inf_hp: float = float(units_config.get("infantry", {}).get("hp", 100))
	var cav_hp: float = float(units_config.get("cavalry", {}).get("hp", 80))
	var art_hp: float = float(units_config.get("artillery", {}).get("hp", 60))
	infantry_hp_pool = infantry_count * inf_hp
	cavalry_hp_pool = cavalry_count * cav_hp
	artillery_hp_pool = artillery_count * art_hp


func get_total_hp() -> float:
	return infantry_hp_pool + cavalry_hp_pool + artillery_hp_pool


func apply_damage_with_priority(damage: float, balance: Dictionary) -> void:
	## Applies damage in priority order: artillery -> cavalry -> infantry.
	## When a unit type's HP pool is depleted, removes units and spills
	## remaining damage to the next type.
	var units_config: Dictionary = balance.get("units", {})
	var remaining := damage

	# Priority 1: Artillery
	if remaining > 0.0 and artillery_hp_pool > 0.0:
		artillery_hp_pool -= remaining
		if artillery_hp_pool <= 0.0:
			remaining = -artillery_hp_pool
			artillery_hp_pool = 0.0
			artillery_count = 0
		else:
			remaining = 0.0
			# Update count based on remaining HP
			var art_hp_each: float = float(units_config.get("artillery", {}).get("hp", 60))
			if art_hp_each > 0:
				artillery_count = ceili(artillery_hp_pool / art_hp_each)

	# Priority 2: Cavalry
	if remaining > 0.0 and cavalry_hp_pool > 0.0:
		cavalry_hp_pool -= remaining
		if cavalry_hp_pool <= 0.0:
			remaining = -cavalry_hp_pool
			cavalry_hp_pool = 0.0
			cavalry_count = 0
		else:
			remaining = 0.0
			var cav_hp_each: float = float(units_config.get("cavalry", {}).get("hp", 80))
			if cav_hp_each > 0:
				cavalry_count = ceili(cavalry_hp_pool / cav_hp_each)

	# Priority 3: Infantry
	if remaining > 0.0 and infantry_hp_pool > 0.0:
		infantry_hp_pool -= remaining
		if infantry_hp_pool <= 0.0:
			infantry_hp_pool = 0.0
			infantry_count = 0
		else:
			var inf_hp_each: float = float(units_config.get("infantry", {}).get("hp", 100))
			if inf_hp_each > 0:
				infantry_count = ceili(infantry_hp_pool / inf_hp_each)


func total_units() -> int:
	return infantry_count + cavalry_count + artillery_count


func total_dps(balance: Dictionary) -> float:
	var units_config: Dictionary = balance.get("units", {})
	var inf_dps: float = float(units_config.get("infantry", {}).get("dps", 0))
	var cav_dps: float = float(units_config.get("cavalry", {}).get("dps", 0))
	var art_dps: float = float(units_config.get("artillery", {}).get("dps", 0))
	return infantry_count * inf_dps + cavalry_count * cav_dps + artillery_count * art_dps


func total_siege_damage(balance: Dictionary) -> float:
	var units_config: Dictionary = balance.get("units", {})
	var inf_siege: float = float(units_config.get("infantry", {}).get("siege_damage", 0))
	var cav_siege: float = float(units_config.get("cavalry", {}).get("siege_damage", 0))
	var art_siege: float = float(units_config.get("artillery", {}).get("siege_damage", 0))
	return infantry_count * inf_siege + cavalry_count * cav_siege + artillery_count * art_siege


func movement_speed(balance: Dictionary) -> float:
	var units_config: Dictionary = balance.get("units", {})
	var min_speed: float = INF

	if infantry_count > 0:
		var spd: float = float(units_config.get("infantry", {}).get("speed", 1.0))
		min_speed = minf(min_speed, spd)
	if cavalry_count > 0:
		var spd: float = float(units_config.get("cavalry", {}).get("speed", 1.0))
		min_speed = minf(min_speed, spd)
	if artillery_count > 0:
		var spd: float = float(units_config.get("artillery", {}).get("speed", 1.0))
		min_speed = minf(min_speed, spd)

	if min_speed == INF:
		return 0.0
	return min_speed


func split(inf: int, cav: int, art: int) -> UnitStack:
	if inf > infantry_count or cav > cavalry_count or art > artillery_count:
		return null
	if inf + cav + art <= 0:
		return null

	infantry_count -= inf
	cavalry_count -= cav
	artillery_count -= art

	var new_stack := UnitStack.new()
	new_stack.owner_id = owner_id
	new_stack.city_id = city_id
	new_stack.infantry_count = inf
	new_stack.cavalry_count = cav
	new_stack.artillery_count = art
	return new_stack


func merge(other: UnitStack) -> bool:
	if other.owner_id != owner_id:
		return false
	if other.city_id != city_id:
		return false

	infantry_count += other.infantry_count
	cavalry_count += other.cavalry_count
	artillery_count += other.artillery_count
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


func take_casualties(inf_lost: int, cav_lost: int, art_lost: int) -> void:
	infantry_count = maxi(infantry_count - inf_lost, 0)
	cavalry_count = maxi(cavalry_count - cav_lost, 0)
	artillery_count = maxi(artillery_count - art_lost, 0)


func add_units(inf: int, cav: int, art: int) -> void:
	infantry_count += inf
	cavalry_count += cav
	artillery_count += art


func is_empty() -> bool:
	return total_units() == 0
