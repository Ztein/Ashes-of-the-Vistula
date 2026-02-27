extends BaseTest
## Integration tests for the GameState coordinator.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_simple_gs() -> GameState:
	## 4 cities: A(major,P0), B(neutral), C(hamlet,P1), D(neutral)
	## Adjacency: A-B, B-C, A-D, B-D
	var map_data := {
		"total_hex_count": 50,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "major_city", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "CityB", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 0]},
			{"id": 2, "name": "CityC", "tier": "hamlet", "production_type": "cavalry", "hex_position": [10, 0]},
			{"id": 3, "name": "CityD", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 5]},
		],
		"adjacency": [[0, 1], [1, 2], [0, 3], [1, 3]],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": -1, "2": 1, "3": -1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 10, "cavalry": 3, "artillery": 2},
			{"owner_id": 1, "city_id": 2, "infantry": 5, "cavalry": 2, "artillery": 1},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	return gs


func _make_full_gs() -> GameState:
	var loader := ConfigLoader.new()
	var gs := GameState.new()
	gs.initialize(loader.load_map(), loader.load_scenario(), _balance)
	return gs


# --- Initialization ---

func test_initializes_cities_from_map_data() -> void:
	var gs := _make_full_gs()
	assert_eq(gs.get_all_cities().size(), 15, "15 cities from map")


func test_initializes_stacks_from_scenario() -> void:
	var gs := _make_full_gs()
	assert_eq(gs.get_all_stacks().size(), 4, "4 starting stacks")


func test_initializes_player_commands() -> void:
	var gs := _make_full_gs()
	assert_gt(gs.get_command_info(0)["order_cap"], 0, "p0 has order cap")
	assert_gt(gs.get_command_info(1)["order_cap"], 0, "p1 has order cap")


# --- Move Commands ---

func test_move_command_spends_order() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	var before: float = gs.get_command_info(0)["current_orders"]
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_true(success, "move should succeed")
	assert_lt(gs.get_command_info(0)["current_orders"], before, "order spent")


func test_move_rejected_not_adjacent() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	# City 0 and 2 are NOT adjacent (path is 0-1-2)
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 2,
	})
	assert_false(success, "non-adjacent move should fail")


func test_move_rejected_unowned_stack() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(1, 2)[0].id
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_false(success, "moving unowned stack should fail")


func test_move_rejected_insufficient_orders() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	# Player 0 cap = 4 (base 3 + 1 major). Drain via 4 splits.
	for i in range(4):
		gs.submit_command({
			"type": "split_stack", "player_id": 0,
			"stack_id": sid, "infantry": 1, "cavalry": 0, "artillery": 0,
		})
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_false(success, "should reject when orders depleted")


# --- Movement ---

func test_stack_moves_and_arrives() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_true(gs.get_stack(sid).is_moving, "should be moving")
	# Speed = min(1.0, 1.5, 0.6) = 0.6. Progress: 0.1*0.6 = 0.06/tick. ~17 ticks.
	for i in range(20):
		gs.tick()
	assert_false(gs.get_stack(sid).is_moving, "should have arrived")
	assert_eq(gs.get_stack(sid).city_id, 1, "at city 1")


# --- Split ---

func test_split_stack_command() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	var inf_before: int = gs.get_stack(sid).infantry_count
	var success := gs.submit_command({
		"type": "split_stack", "player_id": 0,
		"stack_id": sid, "infantry": 3, "cavalry": 0, "artillery": 0,
	})
	assert_true(success, "split should succeed")
	assert_eq(gs.get_stack(sid).infantry_count, inf_before - 3, "original lost 3 inf")
	assert_gte(gs.get_stacks_at_city(0, 0).size(), 2, "new stack created")


# --- Siege ---

func test_siege_reduces_structure_hp() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	# Move 0→1 then 1→2 to reach enemy city
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	var hp_before: float = gs.get_city(2).structure_hp
	gs.submit_command({"type": "start_siege", "player_id": 0, "stack_id": sid})
	for i in range(10):
		gs.tick()
	assert_lt(gs.get_city(2).structure_hp, hp_before, "structure HP should decrease")


# --- Full Siege → Battle → Capture ---

func test_siege_to_battle_to_capture() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	# Move to enemy city via city 1
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()
	gs.submit_command({"type": "start_siege", "player_id": 0, "stack_id": sid})

	assert_eq(gs.get_city(2).owner_id, 1, "city 2 starts as player 1")
	# Tick enough for siege + battle. Attacker (10i+3c+2a) >> Defender (5i+2c+1a).
	for i in range(300):
		gs.tick()
		if gs.get_city(2).owner_id == 0:
			break
	assert_eq(gs.get_city(2).owner_id, 0, "city captured by player 0")


# --- Capture Neutral ---

func test_capture_neutral_city() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	assert_eq(gs.get_city(1).owner_id, -1, "city 1 is neutral")
	var success := gs.submit_command({"type": "capture_neutral", "player_id": 0, "stack_id": sid})
	assert_true(success, "capture neutral should succeed")
	assert_eq(gs.get_city(1).owner_id, 0, "city 1 captured by p0")


# --- Production ---

func test_production_creates_units() -> void:
	var gs := _make_simple_gs()
	var initial: int = gs.get_supply_info(0)["current"]
	# Major city produces infantry every 4.0s. 50 ticks = 5s > 4s interval.
	for i in range(50):
		gs.tick()
	assert_gt(gs.get_supply_info(0)["current"], initial, "units should be produced")


# --- Order Regeneration ---

func test_orders_regenerate() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({
		"type": "split_stack", "player_id": 0,
		"stack_id": sid, "infantry": 1, "cavalry": 0, "artillery": 0,
	})
	var after_spend: float = gs.get_command_info(0)["current_orders"]
	for i in range(20):
		gs.tick()
	assert_gt(gs.get_command_info(0)["current_orders"], after_spend, "orders regenerated")


# --- Determinism ---

func test_determinism_same_commands_same_state() -> void:
	var gs1 := _make_simple_gs()
	var gs2 := _make_simple_gs()
	var sid: int = gs1.get_stacks_at_city(0, 0)[0].id
	gs1.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	gs2.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(50):
		gs1.tick()
		gs2.tick()
	assert_approx(
		gs1.get_command_info(0)["current_orders"],
		gs2.get_command_info(0)["current_orders"],
		0.001, "orders should match"
	)
	assert_eq(
		gs1.get_supply_info(0)["current"],
		gs2.get_supply_info(0)["current"],
		"supply should match"
	)
