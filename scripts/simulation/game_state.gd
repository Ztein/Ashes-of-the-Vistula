class_name GameState
extends RefCounted
## Top-level game state coordinator.
## Owns all simulation subsystems, processes commands, advances the simulation.
## Deterministic: same inputs in same order produce identical outputs.

# Subsystems
var _combat_resolver := CombatResolver.new()
var _supply_system := SupplySystem.new()
var _command_system := CommandSystem.new()
var _territory_system := TerritorySystem.new()
var _dominance_system := DominanceSystem.new()

# Data
var _cities: Dictionary = {}  # int -> City
var _stacks: Dictionary = {}  # int -> UnitStack
var _adjacency: Array = []
var _adjacency_set: Dictionary = {}  # edge_key -> true
var _total_hex_count: int = 200
var _balance: Dictionary = {}
var _player_ids: Array = []
var _next_stack_id: int = 0

# Combat state
var _sieges: Dictionary = {}  # city_id -> { "attacker_id": int }
var _battles: Dictionary = {}  # city_id -> true

# Territory cache
var _territory_cache: Dictionary = {}  # player_id -> int (hex count)

# Game state
var _game_over: bool = false
var _winner_id: int = -1
var _tick_count: int = 0

# Signals
signal city_captured(city_id: int, new_owner: int)
signal siege_started(city_id: int, attacker_player_id: int)
signal battle_started(city_id: int)
signal stack_arrived(stack_id: int, city_id: int)
signal territory_changed(player_id: int)
signal dominance_triggered(player_id: int)
signal dominance_ended(player_id: int)
signal victory_achieved(winner_id: int)
signal production_completed(city_id: int, unit_type: String)


func initialize(map_data: Dictionary, scenario_data: Dictionary, balance: Dictionary) -> void:
	_balance = balance
	_total_hex_count = int(map_data.get("total_hex_count", 200))

	# Load cities
	for city_data in map_data.get("cities", []):
		var city := City.new()
		city.init_from_config(city_data, balance)
		_cities[city.id] = city

	# Build adjacency set for O(1) lookup
	_adjacency = map_data.get("adjacency", [])
	for edge in _adjacency:
		_adjacency_set[_edge_key(int(edge[0]), int(edge[1]))] = true

	# Load players
	for player in scenario_data.get("players", []):
		_player_ids.append(int(player["id"]))

	# Set city ownership
	var ownership: Dictionary = scenario_data.get("city_ownership", {})
	for city_id_str in ownership:
		var city_id: int = int(city_id_str)
		if _cities.has(city_id):
			_cities[city_id].owner_id = int(ownership[city_id_str])

	# Create starting stacks
	for stack_data in scenario_data.get("starting_stacks", []):
		var stack := UnitStack.new()
		stack.id = _next_stack_id
		_next_stack_id += 1
		stack.owner_id = int(stack_data["owner_id"])
		stack.city_id = int(stack_data["city_id"])
		stack.infantry_count = int(stack_data.get("infantry", 0))
		stack.cavalry_count = int(stack_data.get("cavalry", 0))
		stack.artillery_count = int(stack_data.get("artillery", 0))
		_stacks[stack.id] = stack

	# Initialize per-player systems
	for player_id in _player_ids:
		var owned := _get_owned_cities(player_id)
		_command_system.initialize_player(player_id, owned, balance)
		_dominance_system.initialize_player(player_id, balance)
		_territory_cache[player_id] = 0


func submit_command(command: Dictionary) -> bool:
	if _game_over:
		return false

	match command.get("type", ""):
		"move_stack":
			return _cmd_move(command)
		"split_stack":
			return _cmd_split(command)
		"start_siege":
			return _cmd_start_siege(command)
		"capture_neutral":
			return _cmd_capture_neutral(command)
		_:
			return false


func tick() -> void:
	if _game_over:
		return

	var delta: float = float(_balance.get("simulation", {}).get("tick_delta", 0.1))

	_tick_movement(delta)
	_tick_sieges()
	_tick_battles()
	_tick_structure_regen()
	_tick_production(delta)
	_tick_order_regen(delta)
	_recalculate_territory()
	_check_dominance(delta)
	_cleanup_empty_stacks()

	_tick_count += 1


# --- Getters ---

func get_all_cities() -> Array:
	return _cities.values()


func get_city(city_id: int) -> City:
	return _cities.get(city_id)


func get_all_stacks() -> Array:
	return _stacks.values()


func get_stack(stack_id: int) -> UnitStack:
	return _stacks.get(stack_id)


func get_stacks_at_city(player_id: int, city_id: int) -> Array:
	var result: Array = []
	for stack in _stacks.values():
		var s: UnitStack = stack as UnitStack
		if s.owner_id == player_id and s.city_id == city_id and not s.is_moving:
			result.append(s)
	return result


func get_stacks_for_player(player_id: int) -> Array:
	var result: Array = []
	for stack in _stacks.values():
		if (stack as UnitStack).owner_id == player_id:
			result.append(stack)
	return result


func get_command_info(player_id: int) -> Dictionary:
	return _command_system.get_command_info(player_id)


func get_supply_info(player_id: int) -> Dictionary:
	var owned := _get_owned_cities(player_id)
	var hex_count: int = _territory_cache.get(player_id, 0) as int
	return _supply_system.get_supply_info(player_id, owned, get_all_stacks(), hex_count, _balance)


func get_territory_hex_count(player_id: int) -> int:
	return _territory_cache.get(player_id, 0) as int


func is_game_over() -> bool:
	return _game_over


func get_winner() -> int:
	return _winner_id


func get_tick_count() -> int:
	return _tick_count


func is_city_under_siege(city_id: int) -> bool:
	return _sieges.has(city_id)


func is_city_in_battle(city_id: int) -> bool:
	return _battles.has(city_id)


func get_siege_attacker(city_id: int) -> int:
	if _sieges.has(city_id):
		return int(_sieges[city_id]["attacker_id"])
	return -1


func get_dominance_info(player_id: int) -> Dictionary:
	return _dominance_system.get_info(player_id)


func get_total_city_count() -> int:
	return _cities.size()


func count_owned_cities(player_id: int) -> int:
	return _count_owned_cities(player_id)


func get_total_hex_count() -> int:
	return _total_hex_count


# --- Command Processing ---

func _cmd_move(command: Dictionary) -> bool:
	var player_id: int = int(command["player_id"])
	var stack_id: int = int(command["stack_id"])
	var target_city_id: int = int(command["target_city_id"])

	if not _stacks.has(stack_id):
		return false
	var stack: UnitStack = _stacks[stack_id]

	if stack.owner_id != player_id:
		return false
	if stack.is_moving:
		return false
	if not _are_adjacent(stack.city_id, target_city_id):
		return false

	var cost: int = int(_balance.get("command", {}).get("order_costs", {}).get("move_stack", 1))
	if not _command_system.can_afford(player_id, cost):
		return false

	_command_system.spend_order(player_id, cost)
	stack.start_move(target_city_id)
	return true


func _cmd_split(command: Dictionary) -> bool:
	var player_id: int = int(command["player_id"])
	var stack_id: int = int(command["stack_id"])
	var inf: int = int(command.get("infantry", 0))
	var cav: int = int(command.get("cavalry", 0))
	var art: int = int(command.get("artillery", 0))

	if not _stacks.has(stack_id):
		return false
	var stack: UnitStack = _stacks[stack_id]

	if stack.owner_id != player_id:
		return false
	if stack.is_moving:
		return false

	var cost: int = int(_balance.get("command", {}).get("order_costs", {}).get("split_stack", 1))
	if not _command_system.can_afford(player_id, cost):
		return false

	var new_stack: UnitStack = stack.split(inf, cav, art)
	if new_stack == null:
		return false

	_command_system.spend_order(player_id, cost)
	new_stack.id = _next_stack_id
	_next_stack_id += 1
	_stacks[new_stack.id] = new_stack
	return true


func _cmd_start_siege(command: Dictionary) -> bool:
	var player_id: int = int(command["player_id"])
	var stack_id: int = int(command["stack_id"])

	if not _stacks.has(stack_id):
		return false
	var stack: UnitStack = _stacks[stack_id]

	if stack.owner_id != player_id:
		return false
	if stack.is_moving:
		return false

	var city_id: int = stack.city_id
	if not _cities.has(city_id):
		return false
	var city: City = _cities[city_id]

	# Must be enemy city (not own, not neutral)
	if city.owner_id == player_id or city.owner_id < 0:
		return false

	# If siege already active at this city, stack auto-joins (no extra cost)
	if _sieges.has(city_id):
		return true

	var cost: int = int(_balance.get("command", {}).get("order_costs", {}).get("start_siege", 1))
	if not _command_system.can_afford(player_id, cost):
		return false

	_command_system.spend_order(player_id, cost)
	_sieges[city_id] = {"attacker_id": player_id}
	siege_started.emit(city_id, player_id)
	return true


func _cmd_capture_neutral(command: Dictionary) -> bool:
	var player_id: int = int(command["player_id"])
	var stack_id: int = int(command["stack_id"])

	if not _stacks.has(stack_id):
		return false
	var stack: UnitStack = _stacks[stack_id]

	if stack.owner_id != player_id:
		return false
	if stack.is_moving:
		return false

	var city_id: int = stack.city_id
	if not _cities.has(city_id):
		return false
	var city: City = _cities[city_id]

	if city.owner_id >= 0:
		return false

	var cost: int = int(_balance.get("command", {}).get("order_costs", {}).get("capture_neutral", 1))
	if not _command_system.can_afford(player_id, cost):
		return false

	_command_system.spend_order(player_id, cost)
	city.capture(player_id)
	_recalculate_commands_for_player(player_id)
	city_captured.emit(city_id, player_id)
	return true


# --- Tick Sub-steps ---

func _tick_movement(delta: float) -> void:
	for stack_obj in _stacks.values():
		var stack: UnitStack = stack_obj as UnitStack
		if stack.is_moving:
			var speed: float = stack.movement_speed(_balance)
			var arrived := stack.tick_move(delta, speed)
			if arrived:
				# Late arrival to an active battle — init HP pools
				if _battles.has(stack.city_id):
					stack.init_hp_pools(_balance)
				stack_arrived.emit(stack.id, stack.city_id)


func _tick_sieges() -> void:
	var siege_cities := _sieges.keys().duplicate()
	for city_id in siege_cities:
		if _battles.has(city_id):
			continue  # Already in battle phase

		var siege_info: Dictionary = _sieges[city_id]
		var attacker_id: int = int(siege_info["attacker_id"])
		var city: City = _cities[city_id]

		var attacker_stacks := _get_player_stacks_at_city(attacker_id, city_id)
		if attacker_stacks.is_empty():
			_sieges.erase(city_id)
			continue

		var result := _combat_resolver.tick_siege(city, attacker_stacks, _balance)

		if result["transitioned_to_battle"]:
			_battles[city_id] = true
			battle_started.emit(city_id)
			# Init HP pools for all combatants
			for s in attacker_stacks:
				(s as UnitStack).init_hp_pools(_balance)
			var defender_stacks := _get_player_stacks_at_city(city.owner_id, city_id)
			for s in defender_stacks:
				(s as UnitStack).init_hp_pools(_balance)


func _tick_battles() -> void:
	var battle_cities := _battles.keys().duplicate()
	for city_id in battle_cities:
		if not _sieges.has(city_id):
			_battles.erase(city_id)
			continue

		var siege_info: Dictionary = _sieges[city_id]
		var attacker_id: int = int(siege_info["attacker_id"])
		var city: City = _cities[city_id]

		var attacker_stacks := _get_player_stacks_at_city(attacker_id, city_id)
		var defender_stacks := _get_player_stacks_at_city(city.owner_id, city_id)

		if attacker_stacks.is_empty():
			_sieges.erase(city_id)
			_battles.erase(city_id)
			continue

		if defender_stacks.is_empty():
			_capture_city(city_id, attacker_id)
			continue

		var result := _combat_resolver.tick_battle(attacker_stacks, defender_stacks, _balance)

		if result["result"] == CombatResolver.ATTACKER_WIN:
			_capture_city(city_id, attacker_id)
		elif result["result"] == CombatResolver.DEFENDER_WIN:
			_sieges.erase(city_id)
			_battles.erase(city_id)


func _capture_city(city_id: int, new_owner: int) -> void:
	var city: City = _cities[city_id]
	var old_owner: int = city.owner_id
	city.capture(new_owner)
	_sieges.erase(city_id)
	_battles.erase(city_id)

	_recalculate_commands_for_player(new_owner)
	if old_owner >= 0:
		_recalculate_commands_for_player(old_owner)

	city_captured.emit(city_id, new_owner)


func _tick_structure_regen() -> void:
	for city_obj in _cities.values():
		var city: City = city_obj as City
		if not _sieges.has(city.id) and not _battles.has(city.id):
			_combat_resolver.tick_structure_regen(city, _balance)


func _tick_production(delta: float) -> void:
	for city_obj in _cities.values():
		var city: City = city_obj as City
		if city.owner_id < 0:
			continue

		var local_units := _count_units_at_city(city.id)
		var supply_available := not _supply_system.is_at_supply_cap(
			city.owner_id,
			_get_owned_cities(city.owner_id),
			get_all_stacks(),
			_territory_cache.get(city.owner_id, 0) as int,
			_balance
		)

		var produced: String = city.tick_production(delta, local_units, supply_available)
		if produced != "":
			_add_produced_unit(city, produced)
			production_completed.emit(city.id, produced)


func _tick_order_regen(delta: float) -> void:
	for player_id in _player_ids:
		_command_system.tick_regeneration(player_id, delta)


func _recalculate_territory() -> void:
	var all_cities := get_all_cities()
	for player_id in _player_ids:
		var hex_count := _territory_system.get_territory_hex_count(
			player_id, all_cities, _adjacency, _total_hex_count
		)
		var prev_count: int = _territory_cache.get(player_id, 0) as int
		_territory_cache[player_id] = hex_count
		if hex_count != prev_count:
			territory_changed.emit(player_id)


func _check_dominance(delta: float) -> void:
	var total_cities: int = _cities.size()
	for player_id in _player_ids:
		var owned_count := _count_owned_cities(player_id)
		var hex_count: int = _territory_cache.get(player_id, 0) as int

		var result := _dominance_system.tick(
			player_id, delta, owned_count, total_cities,
			hex_count, _total_hex_count, _balance
		)

		if result.get("victory", false):
			_game_over = true
			_winner_id = player_id
			victory_achieved.emit(player_id)
			return


func _cleanup_empty_stacks() -> void:
	var to_remove: Array[int] = []
	for stack_obj in _stacks.values():
		var stack: UnitStack = stack_obj as UnitStack
		if stack.is_empty() and not stack.is_moving:
			to_remove.append(stack.id)
	for sid in to_remove:
		_stacks.erase(sid)


# --- Helpers ---

func _get_owned_cities(player_id: int) -> Array:
	var result: Array = []
	for city_obj in _cities.values():
		if (city_obj as City).owner_id == player_id:
			result.append(city_obj)
	return result


func _count_owned_cities(player_id: int) -> int:
	var count: int = 0
	for city_obj in _cities.values():
		if (city_obj as City).owner_id == player_id:
			count += 1
	return count


func _get_player_stacks_at_city(player_id: int, city_id: int) -> Array:
	var result: Array = []
	for stack_obj in _stacks.values():
		var s: UnitStack = stack_obj as UnitStack
		if s.owner_id == player_id and s.city_id == city_id and not s.is_moving:
			result.append(s)
	return result


func _count_units_at_city(city_id: int) -> int:
	var total: int = 0
	for stack_obj in _stacks.values():
		var s: UnitStack = stack_obj as UnitStack
		if s.city_id == city_id and not s.is_moving:
			total += s.total_units()
	return total


func _add_produced_unit(city: City, unit_type: String) -> void:
	var stacks := _get_player_stacks_at_city(city.owner_id, city.id)
	if not stacks.is_empty():
		var stack: UnitStack = stacks[0]
		match unit_type:
			"infantry": stack.infantry_count += 1
			"cavalry": stack.cavalry_count += 1
			"artillery": stack.artillery_count += 1
	else:
		var stack := UnitStack.new()
		stack.id = _next_stack_id
		_next_stack_id += 1
		stack.owner_id = city.owner_id
		stack.city_id = city.id
		match unit_type:
			"infantry": stack.infantry_count = 1
			"cavalry": stack.cavalry_count = 1
			"artillery": stack.artillery_count = 1
		_stacks[stack.id] = stack


func _are_adjacent(city_a: int, city_b: int) -> bool:
	return _adjacency_set.has(_edge_key(city_a, city_b))


func _edge_key(a: int, b: int) -> int:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return lo * 10000 + hi


func _recalculate_commands_for_player(player_id: int) -> void:
	var owned := _get_owned_cities(player_id)
	_command_system.recalculate(player_id, owned, _balance)
