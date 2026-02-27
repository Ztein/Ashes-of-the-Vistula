extends BaseTest
## Unit tests for the CombatResolver — siege phase.

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
