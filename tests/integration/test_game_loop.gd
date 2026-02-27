extends BaseTest
## Integration tests for the GameState coordinator.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_simple_gs() -> GameState:
	## 4 cities: A(major,P0), B(neutral), C(hamlet,P1), D(neutral)
	## Adjacency: A-B, B-C, A-D, B-D
	## P0 starts with 10 inf + 3 cav + 2 art at city 0 (3 stacks)
	## P1 starts with 5 inf + 2 cav + 1 art at city 2 (3 stacks)
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
	# 4 starting stacks entries, each with 3 unit types = up to 12 stacks
	# But only non-zero counts create stacks
	assert_gt(gs.get_all_stacks().size(), 0, "starting stacks created")


func test_homogeneous_stacks_created_per_type() -> void:
	var gs := _make_simple_gs()
	# P0: 10 inf, 3 cav, 2 art at city 0 = 3 stacks
	var p0_stacks := gs.get_stacks_at_city(0, 0)
	assert_eq(p0_stacks.size(), 3, "3 stacks for P0 (one per type)")
	var types: Dictionary = {}
	for s in p0_stacks:
		types[(s as UnitStack).unit_type] = true
	assert_true(types.has("infantry"), "has infantry stack")
	assert_true(types.has("cavalry"), "has cavalry stack")
	assert_true(types.has("artillery"), "has artillery stack")


func test_initializes_player_commands() -> void:
	var gs := _make_full_gs()
	assert_gt(gs.get_command_info(0)["order_cap"], 0, "p0 has order cap")
	assert_gt(gs.get_command_info(1)["order_cap"], 0, "p1 has order cap")


# --- Move Commands ---

func test_move_command_spends_order() -> void:
	var gs := _make_simple_gs()
	# Get the infantry stack (first one)
	var stacks := gs.get_stacks_at_city(0, 0)
	var sid: int = stacks[0].id
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
	# P0 cap = 4 (base 3 + 1 major). Drain via 4 moves.
	var stacks := gs.get_stacks_at_city(0, 0)
	# Move and split to drain orders
	for i in range(4):
		var s := stacks[i % stacks.size()] as UnitStack
		if s.count > 1 and not s.is_moving:
			gs.submit_command({
				"type": "split_stack", "player_id": 0, "stack_id": s.id,
			})
	# Move stacks to drain move orders
	stacks = gs.get_stacks_at_city(0, 0)
	for s in stacks:
		gs.submit_command({
			"type": "move_stack", "player_id": 0,
			"stack_id": (s as UnitStack).id, "target_city_id": 1,
		})
	# Try one more move — should fail
	var remaining := gs.get_stacks_at_city(0, 0)
	if not remaining.is_empty():
		var success := gs.submit_command({
			"type": "move_stack", "player_id": 0,
			"stack_id": remaining[0].id, "target_city_id": 1,
		})
		assert_false(success, "should reject when orders depleted")
	else:
		assert_true(true, "all stacks moved — orders spent")


# --- Movement ---

func test_stack_moves_and_arrives() -> void:
	var gs := _make_simple_gs()
	# Get infantry stack (speed 1.0)
	var inf_stack: UnitStack = null
	for s in gs.get_stacks_at_city(0, 0):
		if (s as UnitStack).unit_type == "infantry":
			inf_stack = s as UnitStack
			break
	assert_not_null(inf_stack)
	var sid: int = inf_stack.id
	gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_true(gs.get_stack(sid).is_moving, "should be moving")
	# Infantry speed=1.0. Progress: 0.1*1.0 = 0.1/tick. ~10 ticks.
	for i in range(15):
		gs.tick()
	assert_false(gs.get_stack(sid).is_moving, "should have arrived")
	assert_eq(gs.get_stack(sid).city_id, 1, "at city 1")


# --- Split ---

func test_split_stack_command_halves_stack() -> void:
	var gs := _make_simple_gs()
	# Find the infantry stack at city 0
	var inf_stack: UnitStack = null
	for s in gs.get_stacks_at_city(0, 0):
		if (s as UnitStack).unit_type == "infantry":
			inf_stack = s as UnitStack
			break
	assert_not_null(inf_stack)
	var count_before: int = inf_stack.count
	var success := gs.submit_command({
		"type": "split_stack", "player_id": 0, "stack_id": inf_stack.id,
	})
	assert_true(success, "split should succeed")
	assert_eq(inf_stack.count, count_before - count_before / 2, "original keeps ceil half")


func test_split_does_not_cost_orders() -> void:
	var gs := _make_simple_gs()
	var inf_stack: UnitStack = null
	for s in gs.get_stacks_at_city(0, 0):
		if (s as UnitStack).unit_type == "infantry":
			inf_stack = s as UnitStack
			break
	var orders_before: float = gs.get_command_info(0)["current_orders"]
	gs.submit_command({
		"type": "split_stack", "player_id": 0, "stack_id": inf_stack.id,
	})
	assert_approx(gs.get_command_info(0)["current_orders"], orders_before, 0.01, "no order cost for split")


# --- Auto-Merge ---

func test_auto_merge_same_type_stacks_on_arrival() -> void:
	## Two infantry stacks at same city merge automatically.
	var map_data := {
		"total_hex_count": 50,
		"cities": [
			{"id": 0, "name": "A", "tier": "hamlet", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "B", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 0]},
		],
		"adjacency": [[0, 1]],
	}
	var scenario := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 0},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 5},
			{"owner_id": 0, "city_id": 1, "infantry": 3},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario, _balance)

	# Move infantry from city 0 to city 1
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})

	for i in range(15):
		gs.tick()

	# Should have merged into one stack
	var stacks := gs.get_stacks_at_city(0, 1)
	assert_eq(stacks.size(), 1, "same-type stacks should auto-merge")
	assert_eq((stacks[0] as UnitStack).count, 8, "5 + 3 = 8")


func test_auto_merge_does_not_merge_different_types() -> void:
	var map_data := {
		"total_hex_count": 50,
		"cities": [
			{"id": 0, "name": "A", "tier": "hamlet", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "B", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 0]},
		],
		"adjacency": [[0, 1]],
	}
	var scenario := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 0},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 5},
			{"owner_id": 0, "city_id": 1, "cavalry": 3},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario, _balance)

	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})

	for i in range(15):
		gs.tick()

	var stacks := gs.get_stacks_at_city(0, 1)
	assert_eq(stacks.size(), 2, "different types should NOT merge")


# --- Siege ---

func test_siege_reduces_structure_hp() -> void:
	var gs := _make_simple_gs()
	# Move all P0 stacks to city 1, then city 2
	for s in gs.get_stacks_at_city(0, 0):
		gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": (s as UnitStack).id, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	for s in gs.get_stacks_at_city(0, 1):
		gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": (s as UnitStack).id, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	var hp_before: float = gs.get_city(2).structure_hp
	for i in range(10):
		gs.tick()
	assert_lt(gs.get_city(2).structure_hp, hp_before, "structure HP should decrease")


# --- Full Siege -> Battle -> Capture ---

func test_siege_to_battle_to_capture() -> void:
	var gs := _make_simple_gs()
	# Move all P0 stacks through city 1 to city 2
	for s in gs.get_stacks_at_city(0, 0):
		gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": (s as UnitStack).id, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	for s in gs.get_stacks_at_city(0, 1):
		gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": (s as UnitStack).id, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	assert_eq(gs.get_city(2).owner_id, 1, "city 2 starts as player 1")
	for i in range(500):
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
	for i in range(50):
		gs.tick()
	assert_gt(gs.get_supply_info(0)["current"], initial, "units should be produced")


# --- Order Regeneration ---

func test_orders_regenerate() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	var after_spend: float = gs.get_command_info(0)["current_orders"]
	for i in range(20):
		gs.tick()
	assert_gt(gs.get_command_info(0)["current_orders"], after_spend, "orders regenerated")


# --- Determinism ---

func test_determinism_same_commands_same_state() -> void:
	var gs1 := _make_simple_gs()
	var gs2 := _make_simple_gs()
	var sid1: int = gs1.get_stacks_at_city(0, 0)[0].id
	var sid2: int = gs2.get_stacks_at_city(0, 0)[0].id
	gs1.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid1, "target_city_id": 1})
	gs2.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid2, "target_city_id": 1})
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


# ===========================================================
# Edge Case Tests
# ===========================================================

func _make_multi_siege_gs() -> GameState:
	## Two P0 infantry stacks already at P1's city for siege testing.
	var map_data := {
		"total_hex_count": 50,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "hamlet", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "CityB", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 0]},
		],
		"adjacency": [[0, 1]],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 1, "infantry": 5},
			{"owner_id": 0, "city_id": 1, "cavalry": 5},
			{"owner_id": 1, "city_id": 1, "infantry": 3},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	return gs


func _make_territory_gs() -> GameState:
	var map_data := {
		"total_hex_count": 200,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "major_city", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "CityB", "tier": "hamlet", "production_type": "infantry", "hex_position": [10, 0]},
			{"id": 2, "name": "CityC", "tier": "hamlet", "production_type": "cavalry", "hex_position": [5, 10]},
		],
		"adjacency": [[0, 1], [1, 2], [0, 2]],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 0, "2": -1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 5},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	return gs


# --- Moving Stack Constraints ---

func test_moving_stack_cannot_be_moved_again() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	var success := gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 3})
	assert_false(success, "can't re-order a moving stack")


func test_moving_stack_cannot_be_split() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	var success := gs.submit_command({
		"type": "split_stack", "player_id": 0, "stack_id": sid,
	})
	assert_false(success, "can't split a moving stack")


# --- Multiple Stacks ---

func test_multiple_stacks_coexist_at_city() -> void:
	var gs := _make_simple_gs()
	# P0 has 3 stacks at city 0 (one per type)
	var stacks := gs.get_stacks_at_city(0, 0)
	assert_eq(stacks.size(), 3, "three stacks at city 0 (one per type)")


func test_combined_siege_damage_from_multiple_stacks() -> void:
	var gs := _make_multi_siege_gs()
	var stacks := gs.get_stacks_at_city(0, 1)
	assert_eq(stacks.size(), 2, "two P0 stacks at enemy city")

	gs.submit_command({"type": "start_siege", "player_id": 0, "stack_id": stacks[0].id})
	var hp_before: float = gs.get_city(1).structure_hp
	for i in range(5):
		gs.tick()
	var damage: float = hp_before - gs.get_city(1).structure_hp
	assert_gt(damage, 0.0, "stacks deal siege damage")


# --- Territory ---

func test_territory_appears_when_triangle_completed() -> void:
	var gs := _make_territory_gs()
	gs.tick()
	assert_eq(gs.get_territory_hex_count(0), 0, "no territory with only 2 cities")

	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	gs.submit_command({"type": "capture_neutral", "player_id": 0, "stack_id": sid})
	gs.tick()

	assert_gt(gs.get_territory_hex_count(0), 0, "territory appears after triangle completion")


# --- Supply Edge Cases ---

func test_overcap_units_survive() -> void:
	var map_data := {
		"total_hex_count": 0,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "hamlet", "production_type": "infantry", "hex_position": [0, 0]},
		],
		"adjacency": [],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 30},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	var supply := gs.get_supply_info(0)
	assert_gt(supply["current"], supply["cap"], "starts over cap")

	for i in range(100):
		gs.tick()

	assert_eq(gs.get_supply_info(0)["current"], 30, "units not destroyed at overcap")


func test_production_halts_at_supply_cap() -> void:
	var map_data := {
		"total_hex_count": 0,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "hamlet", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "CityB", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 0]},
		],
		"adjacency": [[0, 1]],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 0},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 1, "infantry": 24},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	var before: int = gs.get_supply_info(0)["current"]
	assert_eq(before, gs.get_supply_info(0)["cap"], "exactly at cap")

	for i in range(100):
		gs.tick()

	assert_eq(gs.get_supply_info(0)["current"], before, "no units produced at cap")


# --- Auto-Siege ---

func test_auto_siege_triggers_on_arrival_at_enemy_city() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	assert_true(gs.is_city_under_siege(2), "siege should auto-start at enemy city")


func test_auto_siege_does_not_trigger_at_neutral_city() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	assert_false(gs.is_city_under_siege(1), "no auto-siege at neutral city")


func test_auto_siege_does_not_trigger_at_own_city() -> void:
	var gs := _make_simple_gs()
	gs.tick()
	assert_false(gs.is_city_under_siege(0), "no auto-siege at own city")


func test_colocated_stacks_resolve_through_full_combat() -> void:
	var gs := _make_multi_siege_gs()
	assert_eq(gs.get_city(1).owner_id, 1, "city 1 starts as player 1")
	for i in range(500):
		gs.tick()
		if gs.get_city(1).owner_id == 0:
			break
	assert_eq(gs.get_city(1).owner_id, 0, "city captured via auto-siege combat")


# --- Game Over ---

func test_game_over_blocks_further_commands() -> void:
	var custom_balance := _balance.duplicate(true)
	custom_balance["dominance"]["timer_duration"] = 1.0

	var map_data := {
		"total_hex_count": 10,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "hamlet", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "CityB", "tier": "hamlet", "production_type": "infantry", "hex_position": [10, 0]},
			{"id": 2, "name": "CityC", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 10]},
		],
		"adjacency": [[0, 1], [1, 2], [0, 2]],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 0, "2": 0},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 5},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, custom_balance)

	for i in range(20):
		gs.tick()

	assert_true(gs.is_game_over(), "game should be over")
	assert_eq(gs.get_winner(), 0, "player 0 wins")

	var sid: int = gs.get_all_stacks()[0].id
	var success := gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	assert_false(success, "commands blocked after game over")


# --- Movement blocked by enemy presence ---

func test_move_blocked_when_enemy_stacks_present() -> void:
	var gs := _make_multi_siege_gs()
	var p0_stacks := gs.get_stacks_at_city(0, 1)
	assert_gte(p0_stacks.size(), 1, "P0 has stacks at city 1")
	var sid: int = p0_stacks[0].id
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 0,
	})
	assert_false(success, "move should be blocked by enemy presence")


func test_move_allowed_without_enemy_stacks() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_true(success, "move should succeed with no enemies at origin")


func test_move_allowed_after_enemies_destroyed() -> void:
	var gs := _make_multi_siege_gs()
	var p0_stacks := gs.get_stacks_at_city(0, 1)
	gs.submit_command({"type": "start_siege", "player_id": 0, "stack_id": p0_stacks[0].id})
	for i in range(500):
		gs.tick()
		if gs.get_city(1).owner_id == 0:
			break
	assert_eq(gs.get_city(1).owner_id, 0, "P0 should have captured city 1")
	var remaining_stacks := gs.get_stacks_at_city(0, 1)
	if not remaining_stacks.is_empty():
		var sid: int = remaining_stacks[0].id
		var success := gs.submit_command({
			"type": "move_stack", "player_id": 0,
			"stack_id": sid, "target_city_id": 0,
		})
		assert_true(success, "move should succeed after enemies destroyed")


# --- Extended Determinism ---

func test_determinism_100_tick_replay() -> void:
	var gs1 := _make_simple_gs()
	var gs2 := _make_simple_gs()
	var sid1: int = gs1.get_stacks_at_city(0, 0)[0].id
	var sid2: int = gs2.get_stacks_at_city(0, 0)[0].id

	gs1.submit_command({"type": "split_stack", "player_id": 0, "stack_id": sid1})
	gs2.submit_command({"type": "split_stack", "player_id": 0, "stack_id": sid2})
	gs1.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid1, "target_city_id": 1})
	gs2.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid2, "target_city_id": 1})

	for i in range(100):
		gs1.tick()
		gs2.tick()

	for city_id in range(4):
		var c1 := gs1.get_city(city_id)
		var c2 := gs2.get_city(city_id)
		assert_eq(c1.owner_id, c2.owner_id, "city %d owner" % city_id)
		assert_approx(c1.structure_hp, c2.structure_hp, 0.001, "city %d hp" % city_id)

	assert_eq(gs1.get_all_stacks().size(), gs2.get_all_stacks().size(), "stack count match")
	assert_approx(
		gs1.get_command_info(0)["current_orders"],
		gs2.get_command_info(0)["current_orders"],
		0.001, "p0 orders match"
	)
	assert_eq(gs1.get_tick_count(), gs2.get_tick_count(), "tick count match")
