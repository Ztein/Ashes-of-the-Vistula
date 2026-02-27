class_name CombatResolver
extends RefCounted
## Resolves siege and battle phases of combat.
## Siege: attackers damage structure HP. Defenders untouchable.
## Battle: triggered when structure HP reaches 0. DPS exchange with priority targeting.


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
