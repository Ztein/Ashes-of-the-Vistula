extends BaseTest
## Unit tests for the CombatResolver — siege and battle phases.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_city(tier: String = "hamlet", owner: int = 1) -> City:
	var city_data := {
		"id": 0, "name": "TestCity", "tier": tier,
		"production_type": "infantry", "hex_position": [5, 5],
	}
	var city := City.new()
	city.init_from_config(city_data, _balance)
	city.owner_id = owner
	return city


func _make_stack(inf: int = 3, cav: int = 2, art: int = 1, owner: int = 0) -> UnitStack:
	var stack := UnitStack.new()
	stack.id = 1
	stack.owner_id = owner
	stack.city_id = 0
	stack.infantry_count = inf
	stack.cavalry_count = cav
	stack.artillery_count = art
	stack.init_hp_pools(_balance)
	return stack


# --- Siege Damage ---

func test_siege_deals_total_stack_siege_damage_per_tick() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var attacker := _make_stack(3, 2, 1, 0)
	var initial_hp := city.structure_hp

	var result := resolver.tick_siege(city, [attacker], _balance)

	var expected_damage := attacker.total_siege_damage(_balance) * float(_balance["simulation"]["tick_delta"])
	assert_approx(city.structure_hp, initial_hp - expected_damage, 0.01, "HP reduced by siege damage * tick_delta")
	assert_true(result.has("damage_dealt"), "result should have damage_dealt")


func test_siege_with_multiple_stacks_combines_damage() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("village", 1)
	var stack_a := _make_stack(3, 0, 0, 0)
	var stack_b := _make_stack(0, 0, 2, 0)
	var initial_hp := city.structure_hp

	var result := resolver.tick_siege(city, [stack_a, stack_b], _balance)

	var expected_damage := (stack_a.total_siege_damage(_balance) + stack_b.total_siege_damage(_balance)) * float(_balance["simulation"]["tick_delta"])
	assert_approx(city.structure_hp, initial_hp - expected_damage, 0.01, "combined siege damage")


func test_siege_does_not_damage_defenders() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var attacker := _make_stack(3, 2, 1, 0)
	var defender := _make_stack(2, 1, 0, 1)
	var def_total_before := defender.total_units()

	resolver.tick_siege(city, [attacker], _balance)

	assert_eq(defender.total_units(), def_total_before, "defenders untouched during siege")


func test_structure_hp_reaches_zero_triggers_battle_transition() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var attacker := _make_stack(0, 0, 5, 0)  # heavy artillery

	# Tick until structure destroyed
	var transitioned := false
	for i in range(200):
		var result := resolver.tick_siege(city, [attacker], _balance)
		if result.get("transitioned_to_battle", false):
			transitioned = true
			break

	assert_true(transitioned, "siege should transition to battle when HP reaches 0")
	assert_true(city.is_structure_destroyed(), "city HP should be 0")


func test_structure_regenerates_when_no_attackers() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	city.take_siege_damage(50.0)
	var hp_before := city.structure_hp

	resolver.tick_structure_regen(city, _balance)

	assert_gt(city.structure_hp, hp_before, "structure should regenerate when not besieged")


func test_structure_does_not_regenerate_during_active_siege() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	city.take_siege_damage(50.0)

	# Siege tick damages, does not regen
	var attacker := _make_stack(1, 0, 0, 0)
	var hp_after_damage := city.structure_hp
	resolver.tick_siege(city, [attacker], _balance)

	assert_lt(city.structure_hp, hp_after_damage, "HP should decrease, not regen, during siege")


func test_structure_regen_capped_at_max() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	city.take_siege_damage(1.0)

	# Regen many times
	for i in range(100):
		resolver.tick_structure_regen(city, _balance)

	assert_approx(city.structure_hp, city.max_structure_hp, 0.01, "HP should cap at max")


func test_artillery_heavy_stack_sieges_faster_than_cavalry_heavy() -> void:
	var resolver := CombatResolver.new()
	var city_a := _make_city("hamlet", 1)
	var city_b := _make_city("hamlet", 1)
	var art_stack := _make_stack(0, 0, 3, 0)  # 3 artillery
	var cav_stack := _make_stack(0, 3, 0, 0)  # 3 cavalry

	resolver.tick_siege(city_a, [art_stack], _balance)
	resolver.tick_siege(city_b, [cav_stack], _balance)

	assert_lt(city_a.structure_hp, city_b.structure_hp, "artillery should deal more siege damage")


func test_siege_damage_values_from_config() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var stack := _make_stack(1, 0, 0, 0)  # 1 infantry only

	var hp_before := city.structure_hp
	resolver.tick_siege(city, [stack], _balance)

	# infantry siege_damage = 5, tick_delta = 0.1, so damage = 5 * 0.1 = 0.5
	var expected_damage: float = 5.0 * float(_balance["simulation"]["tick_delta"])
	assert_approx(city.structure_hp, hp_before - expected_damage, 0.01, "damage should match config")


# --- Battle Phase ---

func test_battle_deals_simultaneous_damage_to_both_sides() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack(5, 0, 0, 0)
	var defender := _make_stack(5, 0, 0, 1)
	var att_hp_before := attacker.get_total_hp()
	var def_hp_before := defender.get_total_hp()

	resolver.tick_battle([attacker], [defender], _balance)

	assert_lt(attacker.get_total_hp(), att_hp_before, "attacker should take damage")
	assert_lt(defender.get_total_hp(), def_hp_before, "defender should take damage")


func test_battle_targets_artillery_first() -> void:
	var resolver := CombatResolver.new()
	# Attacker has high DPS, defender has all three types
	var attacker := _make_stack(10, 0, 0, 0)
	var defender := _make_stack(3, 3, 3, 1)
	var def_art_hp_before := defender.artillery_hp_pool

	resolver.tick_battle([attacker], [defender], _balance)

	# Artillery should take damage first (priority target)
	assert_lt(defender.artillery_hp_pool, def_art_hp_before, "artillery targeted first")


func test_battle_targets_cavalry_after_artillery_eliminated() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack(10, 5, 0, 0)
	# Defender: no artillery, has cavalry and infantry
	var defender := _make_stack(5, 3, 0, 1)
	var def_cav_hp_before := defender.cavalry_hp_pool

	resolver.tick_battle([attacker], [defender], _balance)

	assert_lt(defender.cavalry_hp_pool, def_cav_hp_before, "cavalry targeted when no artillery")


func test_battle_targets_infantry_last() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack(10, 0, 0, 0)
	# Defender: only infantry
	var defender := _make_stack(5, 0, 0, 1)
	var def_inf_hp_before := defender.infantry_hp_pool

	resolver.tick_battle([attacker], [defender], _balance)

	assert_lt(defender.infantry_hp_pool, def_inf_hp_before, "infantry targeted when only type")


func test_battle_damage_spills_to_next_priority_type() -> void:
	var resolver := CombatResolver.new()
	# Very strong attacker vs defender with 1 artillery and 5 infantry
	var attacker := _make_stack(20, 10, 0, 0)
	var defender := _make_stack(5, 0, 1, 1)  # 1 artillery, 5 infantry

	# Tick enough times to eliminate artillery
	for i in range(50):
		resolver.tick_battle([attacker], [defender], _balance)
		if defender.artillery_count == 0:
			break

	# Artillery should be eliminated, and infantry should also have taken spill damage
	assert_eq(defender.artillery_count, 0, "artillery should be eliminated")
	assert_lt(defender.infantry_hp_pool, 5.0 * 100.0, "infantry should have taken spill damage")


func test_attacker_wins_when_all_defenders_eliminated() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack(20, 10, 5, 0)
	var defender := _make_stack(2, 0, 0, 1)  # small defender

	# Battle until resolution
	var result_code := CombatResolver.ONGOING
	for i in range(500):
		var result := resolver.tick_battle([attacker], [defender], _balance)
		result_code = result["result"]
		if result_code != CombatResolver.ONGOING:
			break

	assert_eq(result_code, CombatResolver.ATTACKER_WIN, "attacker should win")
	assert_true(defender.is_empty(), "defender should be eliminated")


func test_defender_wins_when_all_attackers_eliminated() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack(1, 0, 0, 0)  # tiny attacker
	var defender := _make_stack(20, 10, 5, 1)

	var result_code := CombatResolver.ONGOING
	for i in range(500):
		var result := resolver.tick_battle([attacker], [defender], _balance)
		result_code = result["result"]
		if result_code != CombatResolver.ONGOING:
			break

	assert_eq(result_code, CombatResolver.DEFENDER_WIN, "defender should win")
	assert_true(attacker.is_empty(), "attacker should be eliminated")


func test_battle_is_deterministic_same_inputs_same_outputs() -> void:
	var resolver_a := CombatResolver.new()
	var resolver_b := CombatResolver.new()

	# Run two identical battles
	var att_a := _make_stack(5, 3, 1, 0)
	var def_a := _make_stack(4, 2, 1, 1)
	var att_b := _make_stack(5, 3, 1, 0)
	var def_b := _make_stack(4, 2, 1, 1)

	for i in range(50):
		resolver_a.tick_battle([att_a], [def_a], _balance)
		resolver_b.tick_battle([att_b], [def_b], _balance)

	assert_eq(att_a.infantry_count, att_b.infantry_count, "deterministic inf count")
	assert_eq(att_a.cavalry_count, att_b.cavalry_count, "deterministic cav count")
	assert_eq(def_a.infantry_count, def_b.infantry_count, "deterministic def inf count")
	assert_approx(att_a.infantry_hp_pool, att_b.infantry_hp_pool, 0.001, "deterministic hp pools")


func test_battle_dps_and_hp_values_from_config() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack(1, 0, 0, 0)  # 1 infantry: hp=100, dps=10
	var defender := _make_stack(1, 0, 0, 1)  # 1 infantry: hp=100, dps=10

	resolver.tick_battle([attacker], [defender], _balance)

	# Each deals 10 dps * 0.1 tick_delta = 1.0 damage per tick
	var tick_delta: float = float(_balance["simulation"]["tick_delta"])
	var expected_hp: float = 100.0 - 10.0 * tick_delta
	assert_approx(attacker.infantry_hp_pool, expected_hp, 0.01, "HP reduced by config DPS")
	assert_approx(defender.infantry_hp_pool, expected_hp, 0.01, "HP reduced by config DPS")
