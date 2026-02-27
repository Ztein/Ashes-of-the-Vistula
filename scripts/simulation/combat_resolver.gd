class_name CombatResolver
extends RefCounted
## Resolves siege and battle phases of combat.
## Siege: attackers damage structure HP. Defenders untouchable.
## Battle: triggered when structure HP reaches 0. DPS exchange with priority targeting.
## Priority targeting across homogeneous stacks: artillery -> cavalry -> infantry.

const ONGOING: int = 0
const ATTACKER_WIN: int = 1
const DEFENDER_WIN: int = 2

const PRIORITY_ORDER: Array = ["artillery", "cavalry", "infantry"]


func tick_siege(city: City, attacker_stacks: Array, balance: Dictionary) -> Dictionary:
	var tick_delta: float = float(balance.get("simulation", {}).get("tick_delta", 0.1))

	# Calculate total siege damage from all attacking stacks
	var total_damage: float = 0.0
	for stack in attacker_stacks:
		total_damage += (stack as UnitStack).total_siege_damage(balance)

	var damage_this_tick: float = total_damage * tick_delta
	city.take_siege_damage(damage_this_tick)

	var result := {
		"damage_dealt": damage_this_tick,
		"structure_hp_remaining": city.structure_hp,
		"transitioned_to_battle": city.is_structure_destroyed(),
	}

	return result


func tick_structure_regen(city: City, balance: Dictionary) -> void:
	var tick_delta: float = float(balance.get("simulation", {}).get("tick_delta", 0.1))
	city.regenerate_structure(tick_delta)


func tick_battle(attacker_stacks: Array, defender_stacks: Array, balance: Dictionary) -> Dictionary:
	var tick_delta: float = float(balance.get("simulation", {}).get("tick_delta", 0.1))

	# Calculate total DPS for each side
	var attacker_dps: float = 0.0
	for stack in attacker_stacks:
		attacker_dps += (stack as UnitStack).total_dps(balance)

	var defender_dps: float = 0.0
	for stack in defender_stacks:
		defender_dps += (stack as UnitStack).total_dps(balance)

	# Apply damage simultaneously (calculate first, then apply)
	var att_damage := attacker_dps * tick_delta
	var def_damage := defender_dps * tick_delta

	# Attackers damage defenders with priority targeting
	_distribute_damage(att_damage, defender_stacks, balance)
	# Defenders damage attackers with priority targeting
	_distribute_damage(def_damage, attacker_stacks, balance)

	# Check battle result
	var attackers_alive := _any_units_alive(attacker_stacks)
	var defenders_alive := _any_units_alive(defender_stacks)

	var result_code: int = ONGOING
	if not defenders_alive:
		result_code = ATTACKER_WIN
	elif not attackers_alive:
		result_code = DEFENDER_WIN

	return {"result": result_code}


func _distribute_damage(total_damage: float, target_stacks: Array, balance: Dictionary) -> void:
	## Distribute damage across stacks in priority order: artillery -> cavalry -> infantry.
	## When a stack is depleted, remaining damage spills to the next priority type.
	var remaining := total_damage

	for utype in PRIORITY_ORDER:
		if remaining <= 0.0:
			break
		for stack in target_stacks:
			var s := stack as UnitStack
			if s.unit_type == utype and not s.is_empty():
				var hp_before: float = s.hp_pool
				s.apply_damage(remaining, balance)
				var hp_consumed: float = hp_before - s.hp_pool
				remaining -= hp_consumed
				if remaining <= 0.0:
					break


func _any_units_alive(stacks: Array) -> bool:
	for stack in stacks:
		if not (stack as UnitStack).is_empty():
			return true
	return false
