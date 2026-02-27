extends BaseTest
## Unit tests for the City simulation class.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_city(tier: String, owner_id: int = 0) -> City:
	var city_data := {
		"id": 0,
		"name": "TestCity",
		"tier": tier,
		"production_type": "infantry",
		"hex_position": [5, 5],
	}
	var city := City.new()
	city.init_from_config(city_data, _balance)
	city.owner_id = owner_id
	return city


# --- Initialization ---

func test_city_initializes_hamlet_with_correct_values() -> void:
	var city := _make_city("hamlet")
	assert_eq(city.tier, "hamlet")
	assert_eq(city.max_structure_hp, 100.0, "hamlet structure HP")
	assert_eq(city.structure_hp, 100.0, "hamlet current HP should equal max")
	assert_eq(city.local_cap, 5, "hamlet local cap")
	assert_approx(city.production_interval, 8.0, 0.01, "hamlet production interval")


func test_city_initializes_village_with_correct_values() -> void:
	var city := _make_city("village")
	assert_eq(city.tier, "village")
	assert_eq(city.max_structure_hp, 200.0, "village structure HP")
	assert_eq(city.local_cap, 10, "village local cap")
	assert_approx(city.production_interval, 6.0, 0.01, "village production interval")


func test_city_initializes_major_city_with_correct_values() -> void:
	var city := _make_city("major_city")
	assert_eq(city.tier, "major_city")
	assert_eq(city.max_structure_hp, 400.0, "major_city structure HP")
	assert_eq(city.local_cap, 20, "major_city local cap")
	assert_approx(city.production_interval, 4.0, 0.01, "major_city production interval")


# --- Siege Damage ---

func test_city_takes_siege_damage() -> void:
	var city := _make_city("hamlet")
	city.take_siege_damage(30.0)
	assert_approx(city.structure_hp, 70.0, 0.01, "HP after 30 damage on 100 HP hamlet")


func test_city_structure_hp_does_not_go_below_zero() -> void:
	var city := _make_city("hamlet")
	city.take_siege_damage(150.0)
	assert_approx(city.structure_hp, 0.0, 0.01, "HP should clamp to 0")


func test_city_is_structure_destroyed_when_hp_zero() -> void:
	var city := _make_city("hamlet")
	city.take_siege_damage(100.0)
	assert_true(city.is_structure_destroyed(), "structure should be destroyed at 0 HP")


func test_city_is_not_destroyed_with_remaining_hp() -> void:
	var city := _make_city("hamlet")
	city.take_siege_damage(50.0)
	assert_false(city.is_structure_destroyed(), "structure should not be destroyed with remaining HP")


# --- Structure Regeneration ---

func test_city_regenerates_structure_hp() -> void:
	var city := _make_city("hamlet")
	city.take_siege_damage(50.0)
	# hamlet regen rate = 2.0 per second, delta = 1.0 sec
	city.regenerate_structure(1.0)
	assert_approx(city.structure_hp, 52.0, 0.01, "HP should increase by regen_rate * delta")


func test_city_structure_hp_does_not_exceed_max() -> void:
	var city := _make_city("hamlet")
	city.take_siege_damage(1.0)
	# Try to regen more than needed
	city.regenerate_structure(10.0)
	assert_approx(city.structure_hp, city.max_structure_hp, 0.01, "HP should clamp to max")


# --- Production ---

func test_city_produces_unit_after_interval() -> void:
	var city := _make_city("hamlet")
	# hamlet production_interval = 8.0
	# Tick enough times to complete one production
	var produced := ""
	for i in range(81):  # 81 ticks at 0.1 delta = 8.1 seconds
		produced = city.tick_production(0.1, 0, true)
		if not produced.is_empty():
			break
	assert_eq(produced, "infantry", "should produce infantry after interval")


func test_city_does_not_produce_at_local_cap() -> void:
	var city := _make_city("hamlet")
	# hamlet local_cap = 5, simulate 5 units already at city
	var produced := city.tick_production(100.0, 5, true)
	assert_eq(produced, "", "should not produce when at local cap")


func test_city_does_not_produce_when_global_supply_capped() -> void:
	var city := _make_city("hamlet")
	var produced := city.tick_production(100.0, 0, false)
	assert_eq(produced, "", "should not produce when global supply is capped")


# --- Capture ---

func test_city_capture_changes_owner_and_resets_hp() -> void:
	var city := _make_city("hamlet", 0)
	city.take_siege_damage(100.0)
	city.capture(1)
	assert_eq(city.owner_id, 1, "owner should change to new player")
	assert_approx(city.structure_hp, city.max_structure_hp, 0.01, "HP should reset to max on capture")


# --- Order Bonuses ---

func test_major_city_provides_order_cap_bonus() -> void:
	var city := _make_city("major_city")
	var bonus := city.get_order_cap_bonus()
	assert_eq(bonus, 1, "major city should provide order cap bonus of 1")


func test_major_city_provides_order_regen_bonus() -> void:
	var city := _make_city("major_city")
	var bonus := city.get_order_regen_bonus()
	assert_approx(bonus, 0.05, 0.001, "major city should provide order regen bonus of 0.05")


func test_hamlet_provides_no_order_bonuses() -> void:
	var city := _make_city("hamlet")
	assert_eq(city.get_order_cap_bonus(), 0, "hamlet should have no order cap bonus")
	assert_approx(city.get_order_regen_bonus(), 0.0, 0.001, "hamlet should have no regen bonus")


func test_village_provides_no_order_bonuses() -> void:
	var city := _make_city("village")
	assert_eq(city.get_order_cap_bonus(), 0, "village should have no order cap bonus")
	assert_approx(city.get_order_regen_bonus(), 0.0, 0.001, "village should have no regen bonus")
