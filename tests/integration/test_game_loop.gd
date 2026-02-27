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


# ===========================================================
# Edge Case Tests (game-state-edge-cases ticket)
# ===========================================================

func _make_multi_siege_gs() -> GameState:
	## Two P0 stacks already at P1's city for siege testing.
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
			{"owner_id": 0, "city_id": 1, "infantry": 5, "cavalry": 0, "artillery": 0},
			{"owner_id": 0, "city_id": 1, "infantry": 5, "cavalry": 0, "artillery": 0},
			{"owner_id": 1, "city_id": 1, "infantry": 3, "cavalry": 0, "artillery": 0},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	return gs


func _make_territory_gs() -> GameState:
	## P0 owns 2 of 3 mutually-adjacent cities. Neutral 3rd completes triangle.
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
			{"owner_id": 0, "city_id": 0, "infantry": 5, "cavalry": 0, "artillery": 0},
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
		"type": "split_stack", "player_id": 0,
		"stack_id": sid, "infantry": 1, "cavalry": 0, "artillery": 0,
	})
	assert_false(success, "can't split a moving stack")


# --- Multiple Stacks ---

func test_multiple_stacks_coexist_at_city() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({
		"type": "split_stack", "player_id": 0,
		"stack_id": sid, "infantry": 3, "cavalry": 0, "artillery": 0,
	})
	var stacks := gs.get_stacks_at_city(0, 0)
	assert_eq(stacks.size(), 2, "two stacks at city 0")
	var total_inf: int = 0
	for s in stacks:
		total_inf += (s as UnitStack).infantry_count
	assert_eq(total_inf, 10, "total infantry preserved across split")


func test_combined_siege_damage_from_multiple_stacks() -> void:
	var gs := _make_multi_siege_gs()
	var stacks := gs.get_stacks_at_city(0, 1)
	assert_eq(stacks.size(), 2, "two P0 stacks at enemy city")

	gs.submit_command({"type": "start_siege", "player_id": 0, "stack_id": stacks[0].id})
	var hp_before: float = gs.get_city(1).structure_hp
	for i in range(5):
		gs.tick()
	var damage: float = hp_before - gs.get_city(1).structure_hp

	# 10 infantry total siege = 10 * 5 = 50/sec, per tick = 5.0, over 5 ticks = 25.0
	# Single 5-inf stack would do: 5 * 5 * 0.1 * 5 = 12.5
	var single_expected: float = 5.0 * float(_balance["units"]["infantry"]["siege_damage"]) * 0.1 * 5.0
	assert_gt(damage, single_expected, "two stacks siege faster than one")


# --- Territory ---

func test_territory_appears_when_triangle_completed() -> void:
	var gs := _make_territory_gs()
	gs.tick()  # Recalculate territory
	assert_eq(gs.get_territory_hex_count(0), 0, "no territory with only 2 cities")

	# Move stack from city 0 to city 2 (neutral, adjacent)
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	gs.submit_command({"type": "capture_neutral", "player_id": 0, "stack_id": sid})
	gs.tick()  # Territory recalc happens in tick

	assert_gt(gs.get_territory_hex_count(0), 0, "territory appears after triangle completion")


# --- Supply Edge Cases ---

func test_overcap_units_survive() -> void:
	## Units over supply cap are NOT destroyed — only production stops.
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
		# Cap: base(20) + 1 hamlet(2) = 22. Current: 30. Over cap by 8.
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 30, "cavalry": 0, "artillery": 0},
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
		# Cap: base(20) + 2 hamlets * per_minor(2) = 24. Units at other city.
		"starting_stacks": [
			{"owner_id": 0, "city_id": 1, "infantry": 24, "cavalry": 0, "artillery": 0},
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
	## Stack arriving at enemy city automatically starts a siege.
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	# At enemy city — siege should auto-trigger
	assert_true(gs.is_city_under_siege(2), "siege should auto-start at enemy city")


func test_auto_siege_deals_structure_damage() -> void:
	## Auto-siege should reduce structure HP without explicit START_SIEGE command.
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 2})
	for i in range(20):
		gs.tick()

	var hp_before: float = gs.get_city(2).structure_hp
	for i in range(10):
		gs.tick()
	assert_lt(gs.get_city(2).structure_hp, hp_before, "auto-siege should damage structure")


func test_auto_siege_does_not_trigger_at_neutral_city() -> void:
	## Stack at a neutral city should NOT auto-start siege.
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	gs.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	for i in range(20):
		gs.tick()
	# City 1 is neutral
	assert_false(gs.is_city_under_siege(1), "no auto-siege at neutral city")


func test_auto_siege_does_not_trigger_at_own_city() -> void:
	## Stack at own city should NOT auto-start siege.
	var gs := _make_simple_gs()
	gs.tick()
	assert_false(gs.is_city_under_siege(0), "no auto-siege at own city")


func test_colocated_stacks_resolve_through_full_combat() -> void:
	## Colocated enemy stacks auto-siege → battle → capture without explicit commands.
	var gs := _make_multi_siege_gs()  # P0 has 2 stacks (10 inf) at city 1 (P1), P1 has 3 inf
	# No explicit START_SIEGE — auto-siege should handle it
	assert_eq(gs.get_city(1).owner_id, 1, "city 1 starts as player 1")
	for i in range(500):
		gs.tick()
		if gs.get_city(1).owner_id == 0:
			break
	assert_eq(gs.get_city(1).owner_id, 0, "city captured via auto-siege combat")


# --- Game Over ---

func test_game_over_blocks_further_commands() -> void:
	var custom_balance := _balance.duplicate(true)
	custom_balance["dominance"]["timer_duration"] = 1.0  # 1 second = 10 ticks

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
			{"owner_id": 0, "city_id": 0, "infantry": 5, "cavalry": 0, "artillery": 0},
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
	## Stacks cannot leave a city where enemy stacks are present.
	var gs := _make_multi_siege_gs()  # P0 has 2 stacks at city 1 (enemy), P1 has 1 stack there
	var p0_stacks := gs.get_stacks_at_city(0, 1)
	assert_gte(p0_stacks.size(), 1, "P0 has stacks at city 1")
	var sid: int = p0_stacks[0].id
	# City 0 is adjacent to city 1. Try to move back.
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 0,
	})
	assert_false(success, "move should be blocked by enemy presence")


func test_move_allowed_without_enemy_stacks() -> void:
	var gs := _make_simple_gs()
	var sid: int = gs.get_stacks_at_city(0, 0)[0].id
	# No enemies at city 0
	var success := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_true(success, "move should succeed with no enemies at origin")


func test_move_allowed_after_enemies_destroyed() -> void:
	## Once enemies are eliminated, the stack should be free to move.
	var gs := _make_multi_siege_gs()
	# Start siege to eliminate P1 defenders
	var p0_stacks := gs.get_stacks_at_city(0, 1)
	gs.submit_command({"type": "start_siege", "player_id": 0, "stack_id": p0_stacks[0].id})
	# Tick until battle resolves — P0 has 10 inf, P1 has 3 inf
	for i in range(500):
		gs.tick()
		if gs.get_city(1).owner_id == 0:
			break
	assert_eq(gs.get_city(1).owner_id, 0, "P0 should have captured city 1")
	# Now P0 stacks should be free to move
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
	var sid: int = gs1.get_stacks_at_city(0, 0)[0].id

	# Same commands on both
	gs1.submit_command({"type": "split_stack", "player_id": 0, "stack_id": sid, "infantry": 3, "cavalry": 0, "artillery": 0})
	gs2.submit_command({"type": "split_stack", "player_id": 0, "stack_id": sid, "infantry": 3, "cavalry": 0, "artillery": 0})
	gs1.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})
	gs2.submit_command({"type": "move_stack", "player_id": 0, "stack_id": sid, "target_city_id": 1})

	for i in range(100):
		gs1.tick()
		gs2.tick()

	# Compare complete state
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
