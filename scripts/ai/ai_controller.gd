class_name AIController
extends RefCounted
## AI opponent using the same command interface as the player.
## Decision hierarchy: defend → attack → capture neutrals → form territory → consolidate.
## All config-driven via balance.json ai section.

var _player_id: int = -1
var _game_state: GameState
var _balance: Dictionary = {}
var _pending_commands: Array = []

# Config
var _evaluation_interval: int = 10
var _aggression: float = 0.6
var _defense_priority: float = 0.8
var _territory_weight: float = 0.7

# Adjacency cache built from GameState
var _adjacency_list: Dictionary = {}  # city_id -> [adjacent_city_ids]
var _adjacency_built: bool = false


func setup(player_id: int, game_state: GameState, balance: Dictionary) -> void:
	_player_id = player_id
	_game_state = game_state
	_balance = balance

	var ai_config: Dictionary = balance.get("ai", {})
	_evaluation_interval = int(ai_config.get("evaluation_interval_ticks", 10))
	_aggression = float(ai_config.get("aggression", 0.6))
	_defense_priority = float(ai_config.get("defense_priority", 0.8))
	_territory_weight = float(ai_config.get("territory_value_weight", 0.7))

	_build_adjacency_cache()


func should_evaluate(tick: int) -> bool:
	if _evaluation_interval <= 0:
		return true
	return tick % _evaluation_interval == 0


func evaluate() -> void:
	_pending_commands.clear()
	_committed_stacks.clear()
	if _game_state == null or _game_state.is_game_over():
		return

	var cmd_info := _game_state.get_command_info(_player_id)
	var available_orders: float = cmd_info.get("current_orders", 0.0)

	if available_orders < 1.0:
		return

	var my_stacks := _get_idle_stacks()
	if my_stacks.is_empty():
		return

	# Priority 1: Defend besieged cities
	available_orders = _evaluate_defense(my_stacks, available_orders)

	# Priority 2: Attack weak enemy cities
	available_orders = _evaluate_attacks(my_stacks, available_orders)

	# Priority 3: Capture neutral cities
	available_orders = _evaluate_neutral_captures(my_stacks, available_orders)

	# Priority 4: Move toward strategic positions (triangle-forming)
	available_orders = _evaluate_strategic_moves(my_stacks, available_orders)


func get_pending_commands() -> Array:
	return _pending_commands


# --- Evaluation Steps ---

func _evaluate_defense(stacks: Array, available_orders: float) -> float:
	if available_orders < 1.0:
		return available_orders

	for city in _game_state.get_all_cities():
		if available_orders < 1.0:
			break
		if city.owner_id != _player_id:
			continue
		if not _game_state.is_city_under_siege(city.id):
			continue

		# City is under siege — find nearest idle stack to send
		var best_stack: UnitStack = null
		var best_strength: int = 0

		for s in stacks:
			var stack: UnitStack = s as UnitStack
			if _is_stack_committed(stack):
				continue
			if stack.city_id == city.id:
				continue
			if _is_adjacent(stack.city_id, city.id):
				if stack.total_units() > best_strength:
					best_strength = stack.total_units()
					best_stack = stack

		if best_stack != null:
			_add_move_command(best_stack, city.id)
			available_orders -= 1.0

	return available_orders


func _evaluate_attacks(stacks: Array, available_orders: float) -> float:
	if available_orders < 1.0:
		return available_orders

	var targets: Array = []
	for city in _game_state.get_all_cities():
		if city.owner_id == _player_id or city.owner_id < 0:
			continue
		var defense_strength: float = city.structure_hp + _count_enemy_units_at(city.id) * 50.0
		targets.append({"city": city, "score": defense_strength})

	targets.sort_custom(func(a, b): return a["score"] < b["score"])

	for target_info in targets:
		if available_orders < 1.0:
			break
		var target_city: City = target_info["city"]

		for s in stacks:
			if available_orders < 1.0:
				break
			var stack: UnitStack = s as UnitStack
			if _is_stack_committed(stack):
				continue

			if stack.city_id == target_city.id:
				_add_siege_command(stack)
				available_orders -= 1.0
				break

			if _is_adjacent(stack.city_id, target_city.id):
				var my_strength: float = stack.total_units() * 10.0
				var threshold: float = target_info["score"] * (1.0 - _aggression)
				if my_strength > threshold:
					_add_move_command(stack, target_city.id)
					available_orders -= 1.0
					break

	return available_orders


func _evaluate_neutral_captures(stacks: Array, available_orders: float) -> float:
	if available_orders < 1.0:
		return available_orders

	var neutrals := _get_scored_neutrals()

	for neutral_info in neutrals:
		if available_orders < 1.0:
			break
		var city: City = neutral_info["city"]

		for s in stacks:
			if available_orders < 1.0:
				break
			var stack: UnitStack = s as UnitStack
			if _is_stack_committed(stack):
				continue

			if stack.city_id == city.id:
				_add_capture_command(stack)
				available_orders -= 1.0
				break

			if _is_adjacent(stack.city_id, city.id):
				_add_move_command(stack, city.id)
				available_orders -= 1.0
				break

	return available_orders


func _evaluate_strategic_moves(stacks: Array, available_orders: float) -> float:
	if available_orders < 1.0:
		return available_orders

	var triangle_targets := _find_triangle_forming_cities()

	for target_id in triangle_targets:
		if available_orders < 1.0:
			break

		for s in stacks:
			if available_orders < 1.0:
				break
			var stack: UnitStack = s as UnitStack
			if _is_stack_committed(stack):
				continue
			if stack.city_id == target_id:
				continue

			var next_city := _find_adjacent_toward(stack.city_id, target_id)
			if next_city >= 0:
				_add_move_command(stack, next_city)
				available_orders -= 1.0
				break

	return available_orders


# --- Command Builders ---

var _committed_stacks: Dictionary = {}


func _is_stack_committed(stack: UnitStack) -> bool:
	return _committed_stacks.has(stack.id) or stack.is_moving or _is_pinned(stack)


func _is_pinned(stack: UnitStack) -> bool:
	## A stack is pinned if enemy stacks are present at the same city.
	for other in _game_state.get_all_stacks():
		var s: UnitStack = other as UnitStack
		if s.owner_id != _player_id and s.city_id == stack.city_id and not s.is_moving and not s.is_empty():
			return true
	return false


func _add_move_command(stack: UnitStack, target_city_id: int) -> void:
	_pending_commands.append({
		"type": "move_stack",
		"player_id": _player_id,
		"stack_id": stack.id,
		"target_city_id": target_city_id,
	})
	_committed_stacks[stack.id] = true


func _add_siege_command(stack: UnitStack) -> void:
	_pending_commands.append({
		"type": "start_siege",
		"player_id": _player_id,
		"stack_id": stack.id,
	})
	_committed_stacks[stack.id] = true


func _add_capture_command(stack: UnitStack) -> void:
	_pending_commands.append({
		"type": "capture_neutral",
		"player_id": _player_id,
		"stack_id": stack.id,
	})
	_committed_stacks[stack.id] = true


# --- Helpers ---

func _build_adjacency_cache() -> void:
	_adjacency_list.clear()
	if _game_state == null:
		return
	var adjacency: Array = _game_state.get_adjacency()
	for edge in adjacency:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		if not _adjacency_list.has(a):
			_adjacency_list[a] = []
		_adjacency_list[a].append(b)
		if not _adjacency_list.has(b):
			_adjacency_list[b] = []
		_adjacency_list[b].append(a)
	_adjacency_built = true


func _get_idle_stacks() -> Array:
	var result: Array = []
	for stack in _game_state.get_stacks_for_player(_player_id):
		var s: UnitStack = stack as UnitStack
		if not s.is_moving and not s.is_empty():
			result.append(s)
	return result


func _is_adjacent(city_a: int, city_b: int) -> bool:
	return _game_state.are_adjacent(city_a, city_b)


func _get_adjacent_cities(city_id: int) -> Array:
	if not _adjacency_built:
		_build_adjacency_cache()
	return _adjacency_list.get(city_id, [])


func _count_enemy_units_at(city_id: int) -> int:
	var total: int = 0
	for stack in _game_state.get_all_stacks():
		var s: UnitStack = stack as UnitStack
		if s.owner_id != _player_id and s.city_id == city_id and not s.is_moving:
			total += s.total_units()
	return total


func _get_scored_neutrals() -> Array:
	var scored: Array = []
	for city in _game_state.get_all_cities():
		if city.owner_id >= 0:
			continue
		var score: float = 1.0

		if _would_form_triangle(city.id):
			score += 5.0 * _territory_weight

		var adj := _get_adjacent_cities(city.id)
		for neighbor_id in adj:
			var neighbor := _game_state.get_city(neighbor_id)
			if neighbor != null and neighbor.owner_id == _player_id:
				score += 1.0

		scored.append({"city": city, "score": score})

	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	return scored


func _would_form_triangle(city_id: int) -> bool:
	var my_neighbors: Array = []
	var adj := _get_adjacent_cities(city_id)

	for neighbor_id in adj:
		var neighbor := _game_state.get_city(neighbor_id)
		if neighbor != null and neighbor.owner_id == _player_id:
			my_neighbors.append(neighbor_id)

	for i in range(my_neighbors.size()):
		for j in range(i + 1, my_neighbors.size()):
			if _is_adjacent(my_neighbors[i], my_neighbors[j]):
				return true
	return false


func _find_triangle_forming_cities() -> Array:
	var targets: Array = []
	for city in _game_state.get_all_cities():
		if city.owner_id == _player_id:
			continue
		if _would_form_triangle(city.id):
			targets.append(city.id)
	return targets


func _find_adjacent_toward(from_city: int, target_city: int) -> int:
	if _is_adjacent(from_city, target_city):
		return target_city

	var best_id: int = -1
	var best_dist: float = INF
	var target_pos: Vector2 = _get_city_hex_pos(target_city)

	for neighbor_id in _get_adjacent_cities(from_city):
		var neighbor_pos := _get_city_hex_pos(neighbor_id)
		var dist := neighbor_pos.distance_to(target_pos)
		if dist < best_dist:
			best_dist = dist
			best_id = neighbor_id

	return best_id


func _get_city_hex_pos(city_id: int) -> Vector2:
	var city := _game_state.get_city(city_id)
	if city != null:
		return Vector2(city.hex_position)
	return Vector2.ZERO
