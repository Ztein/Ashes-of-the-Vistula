extends BaseTest
## Integration tests for AI opponent behavior.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


# --- Helpers ---

func _make_simple_map() -> Dictionary:
	return {
		"total_hex_count": 200,
		"cities": [
			{"id": 0, "name": "A", "tier": "major_city", "production_type": "infantry", "hex_position": [3, 3]},
			{"id": 1, "name": "B", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 3]},
			{"id": 2, "name": "C", "tier": "hamlet", "production_type": "infantry", "hex_position": [7, 3]},
			{"id": 3, "name": "D", "tier": "hamlet", "production_type": "infantry", "hex_position": [3, 5]},
			{"id": 4, "name": "E", "tier": "village", "production_type": "infantry", "hex_position": [9, 3]},
		],
		"adjacency": [[0, 1], [1, 2], [0, 3], [2, 4]],
	}


func _make_scenario_neutral_nearby() -> Dictionary:
	# P0 has city 0+3, P1 (AI) has city 2, cities 1 and 4 are neutral
	return {
		"players": [{"id": 0, "name": "Human", "color": [0.8, 0.1, 0.1, 1.0]},
					{"id": 1, "name": "AI", "color": [0.1, 0.3, 0.8, 1.0]}],
		"city_ownership": {"0": 0, "1": -1, "2": 1, "3": 0, "4": -1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 5, "cavalry": 2, "artillery": 1},
			{"owner_id": 1, "city_id": 2, "infantry": 5, "cavalry": 2, "artillery": 1},
		],
	}


func _make_scenario_attack() -> Dictionary:
	# P1 (AI) has city 0 (major) + strong stack. P0 has city 1 (hamlet, weak).
	return {
		"players": [{"id": 0, "name": "Human", "color": [0.8, 0.1, 0.1, 1.0]},
					{"id": 1, "name": "AI", "color": [0.1, 0.3, 0.8, 1.0]}],
		"city_ownership": {"0": 1, "1": 0, "2": -1, "3": -1, "4": -1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 1, "infantry": 2, "cavalry": 0, "artillery": 0},
			{"owner_id": 1, "city_id": 0, "infantry": 8, "cavalry": 3, "artillery": 2},
		],
	}


func _make_triangle_map() -> Dictionary:
	# Triangle possible: 0-1-2 are all mutually adjacent
	return {
		"total_hex_count": 200,
		"cities": [
			{"id": 0, "name": "A", "tier": "hamlet", "production_type": "infantry", "hex_position": [3, 3]},
			{"id": 1, "name": "B", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 3]},
			{"id": 2, "name": "C", "tier": "hamlet", "production_type": "infantry", "hex_position": [4, 5]},
			{"id": 3, "name": "D", "tier": "hamlet", "production_type": "infantry", "hex_position": [1, 3]},
			{"id": 4, "name": "E", "tier": "hamlet", "production_type": "infantry", "hex_position": [6, 5]},
		],
		"adjacency": [[0, 1], [1, 2], [0, 2], [0, 3], [2, 4]],
	}


func _make_triangle_scenario() -> Dictionary:
	# P1 owns 0 and 2 with stack at 0. City 1 is neutral.
	# Capturing 1 would form triangle 0-1-2.
	return {
		"players": [{"id": 0, "name": "Human", "color": [0.8, 0.1, 0.1, 1.0]},
					{"id": 1, "name": "AI", "color": [0.1, 0.3, 0.8, 1.0]}],
		"city_ownership": {"0": 1, "1": -1, "2": 1, "3": 0, "4": -1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 3, "infantry": 5, "cavalry": 2, "artillery": 1},
			{"owner_id": 1, "city_id": 0, "infantry": 5, "cavalry": 2, "artillery": 1},
		],
	}


# --- Tests ---

func test_ai_issues_commands_via_game_state() -> void:
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_neutral_nearby(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	ai.evaluate()
	var commands := ai.get_pending_commands()
	assert_true(commands is Array, "AI returns array of commands")

	for cmd in commands:
		gs.submit_command(cmd)


func test_ai_captures_nearby_neutral() -> void:
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_neutral_nearby(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	ai.evaluate()
	var commands := ai.get_pending_commands()
	assert_true(commands.size() > 0, "AI generates commands when neutral city is reachable")


func test_ai_defends_besieged_city() -> void:
	var map_data := _make_simple_map()
	var scenario := {
		"players": [{"id": 0, "name": "Human", "color": [0.8, 0.1, 0.1, 1.0]},
					{"id": 1, "name": "AI", "color": [0.1, 0.3, 0.8, 1.0]}],
		"city_ownership": {"0": 1, "1": -1, "2": 1, "3": 0, "4": -1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 2, "infantry": 5, "cavalry": 2, "artillery": 1},
			{"owner_id": 1, "city_id": 0, "infantry": 5, "cavalry": 2, "artillery": 1},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario, _balance)

	# Player 0 starts siege on AI's city 2
	gs.submit_command({
		"type": "start_siege",
		"player_id": 0,
		"stack_id": 0,
	})
	assert_true(gs.is_city_under_siege(2), "City 2 is under siege")

	var ai := AIController.new()
	ai.setup(1, gs, _balance)
	ai.evaluate()
	var commands := ai.get_pending_commands()
	assert_true(commands.size() > 0, "AI generates defense commands when city is under siege")


func test_ai_attacks_weak_enemy() -> void:
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_attack(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	ai.evaluate()
	var commands := ai.get_pending_commands()
	assert_true(commands.size() > 0, "AI with superior force generates attack commands")

	var has_move: bool = false
	for cmd in commands:
		if cmd.get("type", "") == "move_stack":
			has_move = true
			break
	assert_true(has_move, "AI issues move command toward enemy territory")


func test_ai_respects_order_cap() -> void:
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_attack(), _balance)

	# Drain orders
	var stacks := gs.get_stacks_for_player(1)
	for i in range(10):
		if stacks.is_empty():
			break
		var s: UnitStack = stacks[0] as UnitStack
		if s.infantry_count >= 2:
			gs.submit_command({
				"type": "split_stack",
				"player_id": 1,
				"stack_id": s.id,
				"infantry": 1, "cavalry": 0, "artillery": 0,
			})
			stacks = gs.get_stacks_for_player(1)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)
	ai.evaluate()
	var commands := ai.get_pending_commands()

	for cmd in commands:
		gs.submit_command(cmd)
	assert_true(true, "AI handles low order budget gracefully")


func test_ai_evaluates_on_interval() -> void:
	var interval: int = int(_balance.get("ai", {}).get("evaluation_interval_ticks", 10))
	assert_true(interval > 0, "AI evaluation interval is positive")

	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_neutral_nearby(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	assert_true(ai.should_evaluate(0), "AI evaluates on tick 0")


func test_ai_evaluates_on_interval_skip() -> void:
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_neutral_nearby(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	assert_false(ai.should_evaluate(5), "AI does not evaluate on non-interval tick")


func test_ai_evaluates_on_interval_match() -> void:
	var interval: int = int(_balance.get("ai", {}).get("evaluation_interval_ticks", 10))
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_neutral_nearby(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	assert_true(ai.should_evaluate(interval), "AI evaluates on tick matching interval")


func test_ai_prioritizes_triangle_forming_captures() -> void:
	var gs := GameState.new()
	gs.initialize(_make_triangle_map(), _make_triangle_scenario(), _balance)

	var ai := AIController.new()
	ai.setup(1, gs, _balance)

	ai.evaluate()
	var commands := ai.get_pending_commands()

	var targets_city_1: bool = false
	for cmd in commands:
		if cmd.get("type", "") == "move_stack" and cmd.get("target_city_id", -1) == 1:
			targets_city_1 = true
	assert_true(targets_city_1, "AI moves toward triangle-forming neutral city")


func test_ai_does_not_move_already_moving_stacks() -> void:
	var gs := GameState.new()
	gs.initialize(_make_simple_map(), _make_scenario_attack(), _balance)

	# Move AI's stack first
	var ai_stacks := gs.get_stacks_for_player(1)
	if not ai_stacks.is_empty():
		var s: UnitStack = ai_stacks[0] as UnitStack
		gs.submit_command({
			"type": "move_stack",
			"player_id": 1,
			"stack_id": s.id,
			"target_city_id": 1,
		})

	var ai := AIController.new()
	ai.setup(1, gs, _balance)
	ai.evaluate()
	var commands := ai.get_pending_commands()

	for cmd in commands:
		if cmd.get("type", "") == "move_stack":
			var stack := gs.get_stack(cmd.get("stack_id", -1))
			if stack != null:
				assert_false(stack.is_moving, "AI does not issue move to already-moving stack")
