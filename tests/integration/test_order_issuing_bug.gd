extends BaseTest
## Tests for the order issuing bug: phantom stacks, stale sieges, stale selection.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_combat_gs() -> GameState:
	## 3 cities: A(major,P0) - B(hamlet,P1) - C(hamlet,P1)
	## Adjacency: A-B, B-C
	## P0: 5 infantry at A, P1: 3 infantry at B, 2 infantry at C
	var map_data := {
		"total_hex_count": 50,
		"cities": [
			{"id": 0, "name": "CityA", "tier": "major_city", "production_type": "infantry", "hex_position": [0, 0]},
			{"id": 1, "name": "CityB", "tier": "hamlet", "production_type": "infantry", "hex_position": [5, 0]},
			{"id": 2, "name": "CityC", "tier": "hamlet", "production_type": "infantry", "hex_position": [10, 0]},
		],
		"adjacency": [[0, 1], [1, 2]],
	}
	var scenario_data := {
		"players": [{"id": 0, "name": "P0"}, {"id": 1, "name": "P1"}],
		"city_ownership": {"0": 0, "1": 1, "2": 1},
		"starting_stacks": [
			{"owner_id": 0, "city_id": 0, "infantry": 5},
			{"owner_id": 1, "city_id": 1, "infantry": 3},
			{"owner_id": 1, "city_id": 2, "infantry": 2},
		],
	}
	var gs := GameState.new()
	gs.initialize(map_data, scenario_data, _balance)
	return gs


# --- Cause 1: _get_player_stacks_at_city filters out empty stacks ---

func test_get_stacks_at_city_excludes_empty_stacks() -> void:
	## The public get_stacks_at_city should not return stacks with hp_pool=0.
	var gs := _make_combat_gs()
	var stacks := gs.get_stacks_at_city(0, 0)
	assert_eq(stacks.size(), 1, "P0 has 1 stack at city 0")

	# Manually destroy the stack's HP to simulate combat death
	var stack: UnitStack = stacks[0]
	stack.hp_pool = 0.0
	stack.count = 0

	# Query again — should not return the dead stack
	var after := gs.get_stacks_at_city(0, 0)
	assert_eq(after.size(), 0, "dead stack should not appear in get_stacks_at_city")


func test_siege_cleaned_up_when_all_attackers_dead() -> void:
	## If attackers die during battle, siege state must be cleaned up.
	## Regression: phantom stacks kept siege alive forever.
	var gs := _make_combat_gs()

	# Move P0 stack to city 1 (P1's city)
	var p0_stacks := gs.get_stacks_at_city(0, 0)
	var sid: int = (p0_stacks[0] as UnitStack).id
	gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})

	# Tick until the stack arrives (movement completes)
	for i in range(200):
		gs.tick()
		var stack := gs.get_stack(sid)
		if stack == null or (not stack.is_moving and stack.city_id == 1):
			break

	# Now manually kill the attacker stack to simulate combat outcome
	var stack := gs.get_stack(sid)
	if stack != null:
		stack.hp_pool = 0.0
		stack.count = 0

	# Tick a few more times — siege should be cleaned up
	for i in range(10):
		gs.tick()

	assert_true(not gs.is_city_under_siege(1), "siege should be cleaned up after attackers die")
	assert_true(not gs.is_city_in_battle(1), "battle should be cleaned up after attackers die")


func test_production_resumes_after_siege_cleanup() -> void:
	## If a siege is cleaned up, the city should resume production.
	## Regression: phantom stacks kept siege alive, permanently blocking production.
	var gs := _make_combat_gs()

	# Move P0 stack to city 1
	var p0_stacks := gs.get_stacks_at_city(0, 0)
	var sid: int = (p0_stacks[0] as UnitStack).id
	gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})

	# Tick until arrival + siege begins
	for i in range(200):
		gs.tick()
		var stack := gs.get_stack(sid)
		if stack == null or (not stack.is_moving and stack.city_id == 1):
			break

	# Kill the attacker
	var stack := gs.get_stack(sid)
	if stack != null:
		stack.hp_pool = 0.0
		stack.count = 0

	# Tick to clean up
	for i in range(10):
		gs.tick()

	# Verify siege is gone and production is not blocked
	assert_true(not gs.is_city_under_siege(1), "siege gone")

	# City 1 should be able to produce — tick many times and check for new stacks
	var initial_defender_count: int = 0
	for s in gs.get_all_stacks():
		var us: UnitStack = s as UnitStack
		if us.owner_id == 1 and us.city_id == 1:
			initial_defender_count += us.count

	# Tick enough for production to happen
	for i in range(1000):
		gs.tick()

	var final_defender_count: int = 0
	for s in gs.get_all_stacks():
		var us: UnitStack = s as UnitStack
		if us.owner_id == 1 and us.city_id == 1:
			final_defender_count += us.count

	assert_gt(final_defender_count, initial_defender_count, "city should produce after siege cleanup")


# --- Cause 2: Battle with both sides dead should resolve cleanly ---

func test_battle_resolves_when_both_sides_eliminated() -> void:
	## If both attacker and defender stacks are wiped out, siege/battle must be
	## cleaned up — no permanent zombie combat state.
	var gs := _make_combat_gs()

	# Move P0 stack to city 1
	var p0_stacks := gs.get_stacks_at_city(0, 0)
	var sid: int = (p0_stacks[0] as UnitStack).id
	gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})

	# Tick until arrival
	for i in range(200):
		gs.tick()
		var stack := gs.get_stack(sid)
		if stack == null or (not stack.is_moving and stack.city_id == 1):
			break

	# Kill both sides
	for s in gs.get_all_stacks():
		var us: UnitStack = s as UnitStack
		if us.city_id == 1 and not us.is_moving:
			us.hp_pool = 0.0
			us.count = 0

	# Tick to process cleanup
	for i in range(10):
		gs.tick()

	assert_true(not gs.is_city_under_siege(1), "siege cleaned up after both sides die")
	assert_true(not gs.is_city_in_battle(1), "battle cleaned up after both sides die")


# --- Cause 4: Stale selected stack reference ---

func test_stale_stack_selection_move_command_rejected() -> void:
	## If a selected stack is destroyed (cleaned up), issuing a move command
	## with that stack ID should be rejected (return false), not silently fail.
	var gs := _make_combat_gs()

	var p0_stacks := gs.get_stacks_at_city(0, 0)
	var sid: int = (p0_stacks[0] as UnitStack).id

	# Kill the stack and clean up
	var stack := gs.get_stack(sid)
	stack.hp_pool = 0.0
	stack.count = 0
	# Tick to trigger cleanup
	for i in range(5):
		gs.tick()

	# Attempt move with the now-deleted stack ID
	var result := gs.submit_command({
		"type": "move_stack", "player_id": 0,
		"stack_id": sid, "target_city_id": 1,
	})
	assert_true(not result, "move with deleted stack should be rejected")


func test_stale_stack_selection_siege_command_rejected() -> void:
	## Same as above but for siege command.
	var gs := _make_combat_gs()

	var p0_stacks := gs.get_stacks_at_city(0, 0)
	var sid: int = (p0_stacks[0] as UnitStack).id

	# Kill and clean up
	var stack := gs.get_stack(sid)
	stack.hp_pool = 0.0
	stack.count = 0
	for i in range(5):
		gs.tick()

	var result := gs.submit_command({
		"type": "start_siege", "player_id": 0,
		"stack_id": sid,
	})
	assert_true(not result, "siege with deleted stack should be rejected")
