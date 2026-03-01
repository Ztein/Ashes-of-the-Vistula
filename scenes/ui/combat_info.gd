extends PanelContainer
## Displays active combat details for the selected city.
## Shows siege/battle phase, attacker/defender stacks, DPS, HP, and estimated breach time.

@onready var _label: Label = $MarginContainer/VBoxContainer/InfoLabel


func update_display(city_id: int, game_state: GameState, balance: Dictionary) -> void:
	if city_id < 0:
		visible = false
		return

	var is_siege: bool = game_state.is_city_under_siege(city_id)
	var is_battle: bool = game_state.is_city_in_battle(city_id)

	if not is_siege and not is_battle:
		visible = false
		return

	var city: City = game_state.get_city(city_id)
	if city == null:
		visible = false
		return

	var attacker_id: int = game_state.get_siege_attacker(city_id)
	var defender_id: int = city.owner_id

	var attacker_stacks: Array = game_state.get_stacks_at_city(attacker_id, city_id)
	var defender_stacks: Array = game_state.get_stacks_at_city(defender_id, city_id)

	var lines: PackedStringArray = []

	# Header
	lines.append("[%s] %s" % [city.city_name, "BATTLE" if is_battle else "SIEGE"])
	lines.append("")

	if is_battle:
		_build_battle_info(lines, attacker_stacks, defender_stacks, attacker_id, defender_id, balance)
	else:
		_build_siege_info(lines, city, attacker_stacks, defender_stacks, attacker_id, defender_id, balance)

	_label.text = "\n".join(lines)
	visible = true


func _build_siege_info(lines: PackedStringArray, city: City, attacker_stacks: Array, defender_stacks: Array, attacker_id: int, defender_id: int, balance: Dictionary) -> void:
	# Structure HP bar
	var hp_pct: float = 0.0
	if city.max_structure_hp > 0.0:
		hp_pct = (city.structure_hp / city.max_structure_hp) * 100.0
	lines.append("Structure: %.0f / %.0f (%.0f%%)" % [city.structure_hp, city.max_structure_hp, hp_pct])

	# Total siege DPS
	var total_siege_dps: float = 0.0
	for stack in attacker_stacks:
		total_siege_dps += (stack as UnitStack).total_siege_damage(balance)
	lines.append("Siege DPS: %.1f" % total_siege_dps)

	# Estimated time to breach
	if total_siege_dps > 0.0:
		var eta: float = city.structure_hp / total_siege_dps
		lines.append("Breach in: %.1fs" % eta)
	else:
		lines.append("Breach in: never")

	lines.append("")

	# Attacker side
	lines.append("--- ATTACKER (P%d) ---" % attacker_id)
	_build_stack_list(lines, attacker_stacks, balance, true)

	lines.append("")

	# Defender side (behind walls)
	lines.append("--- DEFENDER (P%d) ---" % defender_id)
	if defender_stacks.is_empty():
		lines.append("  (no garrison)")
	else:
		_build_stack_list(lines, defender_stacks, balance, false)
		lines.append("  [behind walls]")


func _build_battle_info(lines: PackedStringArray, attacker_stacks: Array, defender_stacks: Array, attacker_id: int, defender_id: int, balance: Dictionary) -> void:
	# Attacker summary
	var att_total_dps: float = 0.0
	var att_total_hp: float = 0.0
	var att_total_units: int = 0
	for stack in attacker_stacks:
		var s := stack as UnitStack
		att_total_dps += s.total_dps(balance)
		att_total_hp += s.hp_pool
		att_total_units += s.count

	# Defender summary
	var def_total_dps: float = 0.0
	var def_total_hp: float = 0.0
	var def_total_units: int = 0
	for stack in defender_stacks:
		var s := stack as UnitStack
		def_total_dps += s.total_dps(balance)
		def_total_hp += s.hp_pool
		def_total_units += s.count

	# Attacker side
	lines.append("--- ATTACKER (P%d) ---" % attacker_id)
	lines.append("Units: %d  |  DPS: %.1f  |  HP: %.0f" % [att_total_units, att_total_dps, att_total_hp])
	_build_stack_list(lines, attacker_stacks, balance, false)

	lines.append("")

	# Defender side
	lines.append("--- DEFENDER (P%d) ---" % defender_id)
	lines.append("Units: %d  |  DPS: %.1f  |  HP: %.0f" % [def_total_units, def_total_dps, def_total_hp])
	_build_stack_list(lines, defender_stacks, balance, false)

	# Targeting info
	lines.append("")
	var target_type: String = _get_current_target_type(defender_stacks)
	if target_type != "":
		lines.append("Targeting: %s" % target_type.capitalize())


func _build_stack_list(lines: PackedStringArray, stacks: Array, balance: Dictionary, show_siege: bool) -> void:
	for stack in stacks:
		var s := stack as UnitStack
		if s.is_empty():
			continue
		var type_short: String = s.unit_type.substr(0, 3).capitalize()
		if show_siege:
			lines.append("  %s x%d  DPS:%.1f  Siege:%.1f" % [type_short, s.count, s.total_dps(balance), s.total_siege_damage(balance)])
		else:
			lines.append("  %s x%d  DPS:%.1f  HP:%.0f" % [type_short, s.count, s.total_dps(balance), s.hp_pool])


func _get_current_target_type(defender_stacks: Array) -> String:
	## Returns the unit type currently being focused by priority targeting.
	const PRIORITY: Array = ["artillery", "cavalry", "infantry"]
	for utype in PRIORITY:
		for stack in defender_stacks:
			var s := stack as UnitStack
			if s.unit_type == utype and not s.is_empty():
				return utype
	return ""
