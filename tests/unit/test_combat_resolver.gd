extends BaseTest
## Unit tests for the CombatResolver — siege and battle phases.
## With homogeneous stacks, each stack has one unit type.

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


func _make_stack(utype: String = "infantry", ucount: int = 3, owner: int = 0) -> UnitStack:
	var stack := UnitStack.new()
	stack.id = 1
	stack.owner_id = owner
	stack.city_id = 0
	stack.unit_type = utype
	stack.count = ucount
	stack.init_hp_pools(_balance)
	return stack


# --- Siege Damage ---

func test_siege_deals_total_stack_siege_damage_per_tick() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var attacker := _make_stack("infantry", 3, 0)
	var initial_hp := city.structure_hp

	var result := resolver.tick_siege(city, [attacker], _balance)

	var expected_damage := attacker.total_siege_damage(_balance) * float(_balance["simulation"]["tick_delta"])
	assert_approx(city.structure_hp, initial_hp - expected_damage, 0.01, "HP reduced by siege damage * tick_delta")
	assert_true(result.has("damage_dealt"), "result should have damage_dealt")


func test_siege_with_multiple_stacks_combines_damage() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("village", 1)
	var stack_a := _make_stack("infantry", 3, 0)
	var stack_b := _make_stack("artillery", 2, 0)
	var initial_hp := city.structure_hp

	var result := resolver.tick_siege(city, [stack_a, stack_b], _balance)

	var expected_damage := (stack_a.total_siege_damage(_balance) + stack_b.total_siege_damage(_balance)) * float(_balance["simulation"]["tick_delta"])
	assert_approx(city.structure_hp, initial_hp - expected_damage, 0.01, "combined siege damage")


func test_siege_does_not_damage_defenders() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var attacker := _make_stack("infantry", 3, 0)
	var defender := _make_stack("infantry", 2, 1)
	var def_total_before := defender.total_units()

	resolver.tick_siege(city, [attacker], _balance)

	assert_eq(defender.total_units(), def_total_before, "defenders untouched during siege")


func test_structure_hp_reaches_zero_triggers_battle_transition() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var attacker := _make_stack("artillery", 5, 0)  # heavy artillery

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

	var attacker := _make_stack("infantry", 1, 0)
	var hp_after_damage := city.structure_hp
	resolver.tick_siege(city, [attacker], _balance)

	assert_lt(city.structure_hp, hp_after_damage, "HP should decrease, not regen, during siege")


func test_structure_regen_capped_at_max() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	city.take_siege_damage(1.0)

	for i in range(100):
		resolver.tick_structure_regen(city, _balance)

	assert_approx(city.structure_hp, city.max_structure_hp, 0.01, "HP should cap at max")


func test_artillery_heavy_stack_sieges_faster_than_cavalry_heavy() -> void:
	var resolver := CombatResolver.new()
	var city_a := _make_city("hamlet", 1)
	var city_b := _make_city("hamlet", 1)
	var art_stack := _make_stack("artillery", 3, 0)
	var cav_stack := _make_stack("cavalry", 3, 0)

	resolver.tick_siege(city_a, [art_stack], _balance)
	resolver.tick_siege(city_b, [cav_stack], _balance)

	assert_lt(city_a.structure_hp, city_b.structure_hp, "artillery should deal more siege damage")


func test_siege_damage_values_from_config() -> void:
	var resolver := CombatResolver.new()
	var city := _make_city("hamlet", 1)
	var stack := _make_stack("infantry", 1, 0)

	var hp_before := city.structure_hp
	resolver.tick_siege(city, [stack], _balance)

	var expected_damage: float = 5.0 * float(_balance["simulation"]["tick_delta"])
	assert_approx(city.structure_hp, hp_before - expected_damage, 0.01, "damage should match config")


# --- Battle Phase ---

func test_battle_deals_simultaneous_damage_to_both_sides() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 5, 0)
	var defender := _make_stack("infantry", 5, 1)
	var att_hp_before := attacker.get_total_hp()
	var def_hp_before := defender.get_total_hp()

	resolver.tick_battle([attacker], [defender], _balance)

	assert_lt(attacker.get_total_hp(), att_hp_before, "attacker should take damage")
	assert_lt(defender.get_total_hp(), def_hp_before, "defender should take damage")


func test_battle_targets_artillery_first() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 10, 0)
	var def_art := _make_stack("artillery", 3, 1)
	var def_cav := _make_stack("cavalry", 3, 1)
	var def_inf := _make_stack("infantry", 3, 1)
	var art_hp_before := def_art.hp_pool

	resolver.tick_battle([attacker], [def_art, def_cav, def_inf], _balance)

	assert_lt(def_art.hp_pool, art_hp_before, "artillery targeted first")


func test_battle_targets_cavalry_after_artillery_eliminated() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 10, 0)
	var def_cav := _make_stack("cavalry", 3, 1)
	var def_inf := _make_stack("infantry", 5, 1)
	var cav_hp_before := def_cav.hp_pool

	resolver.tick_battle([attacker], [def_cav, def_inf], _balance)

	assert_lt(def_cav.hp_pool, cav_hp_before, "cavalry targeted when no artillery")


func test_battle_targets_infantry_last() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 10, 0)
	var defender := _make_stack("infantry", 5, 1)
	var inf_hp_before := defender.hp_pool

	resolver.tick_battle([attacker], [defender], _balance)

	assert_lt(defender.hp_pool, inf_hp_before, "infantry targeted when only type")


func test_battle_damage_spills_to_next_priority_type() -> void:
	var resolver := CombatResolver.new()
	# 100 infantry = 100 DPS/tick → exceeds artillery's 60 HP, so damage spills
	var attacker := _make_stack("infantry", 100, 0)
	var def_art := _make_stack("artillery", 1, 1)
	var def_inf := _make_stack("infantry", 5, 1)

	resolver.tick_battle([attacker], [def_art, def_inf], _balance)

	assert_eq(def_art.count, 0, "artillery should be eliminated")
	assert_lt(def_inf.hp_pool, 5.0 * 100.0, "infantry should have taken spill damage")


func test_attacker_wins_when_all_defenders_eliminated() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 20, 0)
	var defender := _make_stack("infantry", 2, 1)

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
	var attacker := _make_stack("infantry", 1, 0)
	var defender := _make_stack("infantry", 20, 1)

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

	var att_a := _make_stack("infantry", 5, 0)
	var def_a := _make_stack("infantry", 4, 1)
	var att_b := _make_stack("infantry", 5, 0)
	var def_b := _make_stack("infantry", 4, 1)

	for i in range(50):
		resolver_a.tick_battle([att_a], [def_a], _balance)
		resolver_b.tick_battle([att_b], [def_b], _balance)

	assert_eq(att_a.count, att_b.count, "deterministic att count")
	assert_eq(def_a.count, def_b.count, "deterministic def count")
	assert_approx(att_a.hp_pool, att_b.hp_pool, 0.001, "deterministic hp pools")


func test_battle_dps_and_hp_values_from_config() -> void:
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 1, 0)
	var defender := _make_stack("infantry", 1, 1)

	resolver.tick_battle([attacker], [defender], _balance)

	var tick_delta: float = float(_balance["simulation"]["tick_delta"])
	var expected_hp: float = 100.0 - 10.0 * tick_delta
	assert_approx(attacker.hp_pool, expected_hp, 0.01, "HP reduced by config DPS")
	assert_approx(defender.hp_pool, expected_hp, 0.01, "HP reduced by config DPS")


# --- Bug Fix: phantom stacks with zero HP pool ---

func test_battle_skips_zero_hp_pool_stacks() -> void:
	# Bug 4+5: A stack with count>0 but hp_pool=0.0 should not block battle resolution.
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 10, 0)

	# Create a phantom defender: count>0 but no HP
	var phantom := UnitStack.new()
	phantom.id = 99
	phantom.owner_id = 1
	phantom.city_id = 0
	phantom.unit_type = "infantry"
	phantom.count = 5
	# hp_pool = 0.0 (not initialized)

	# Battle with only phantom defender should result in attacker win
	var result := resolver.tick_battle([attacker], [phantom], _balance)
	assert_eq(result["result"], CombatResolver.ATTACKER_WIN, "phantom defender should not block attacker win")


func test_battle_resolves_with_overwhelming_force_no_phantom_survivors() -> void:
	# End-to-end: 20 infantry vs 1 infantry. Battle must resolve, no phantom survivors.
	var resolver := CombatResolver.new()
	var attacker := _make_stack("infantry", 20, 0)
	var defender := _make_stack("infantry", 1, 1)

	var result_code := CombatResolver.ONGOING
	for i in range(500):
		var result := resolver.tick_battle([attacker], [defender], _balance)
		result_code = result["result"]
		if result_code != CombatResolver.ONGOING:
			break

	assert_eq(result_code, CombatResolver.ATTACKER_WIN, "attacker should win decisively")
	assert_eq(defender.count, 0, "defender count should be 0")
	assert_approx(defender.hp_pool, 0.0, 0.01, "defender HP pool should be 0")
