extends BaseTest
## Unit tests for the SupplySystem.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_city(tier: String = "hamlet", owner: int = 0) -> City:
	var city_data := {
		"id": 0, "name": "TestCity", "tier": tier,
		"production_type": "infantry", "hex_position": [5, 5],
	}
	var city := City.new()
	city.init_from_config(city_data, _balance)
	city.owner_id = owner
	return city


func _make_stack(units: int = 5, owner: int = 0) -> UnitStack:
	var stack := UnitStack.new()
	stack.owner_id = owner
	stack.infantry_count = units
	return stack


# --- Supply Cap ---

func test_base_supply_cap_from_config() -> void:
	var system := SupplySystem.new()
	var cap := system.calculate_supply_cap(0, [], 0, _balance)
	# base_cap = 20
	assert_eq(cap, 20, "base cap should be 20 with no cities or territory")


func test_major_city_increases_supply_cap() -> void:
	var system := SupplySystem.new()
	var major := _make_city("major_city", 0)
	var cap := system.calculate_supply_cap(0, [major], 0, _balance)
	# base_cap(20) + per_major_city(5) = 25
	assert_eq(cap, 25, "major city adds 5 supply")


func test_minor_city_increases_supply_cap() -> void:
	var system := SupplySystem.new()
	var hamlet := _make_city("hamlet", 0)
	var village := _make_city("village", 0)
	var cap := system.calculate_supply_cap(0, [hamlet, village], 0, _balance)
	# base_cap(20) + 2*per_minor_city(2) = 24
	assert_eq(cap, 24, "two minor cities add 4 supply")


func test_territory_hexes_increase_supply_cap() -> void:
	var system := SupplySystem.new()
	var cap := system.calculate_supply_cap(0, [], 10, _balance)
	# base_cap(20) + floor(10 * 0.5) = 25
	assert_eq(cap, 25, "10 territory hexes add 5 supply")


func test_supply_cap_with_no_cities_is_base_only() -> void:
	var system := SupplySystem.new()
	var cap := system.calculate_supply_cap(0, [], 0, _balance)
	assert_eq(cap, 20, "no cities = base only")


func test_current_supply_counts_all_units_across_stacks() -> void:
	var system := SupplySystem.new()
	var stack_a := _make_stack(5, 0)
	var stack_b := _make_stack(3, 0)
	var current := system.calculate_current_supply(0, [stack_a, stack_b])
	assert_eq(current, 8, "5 + 3 = 8 units")


func test_at_cap_true_when_units_equal_cap() -> void:
	var system := SupplySystem.new()
	var stack := _make_stack(20, 0)  # exactly at base cap
	var result := system.is_at_supply_cap(0, [], [stack], 0, _balance)
	assert_true(result, "should be at cap when units = cap")


func test_at_cap_true_when_units_exceed_cap() -> void:
	var system := SupplySystem.new()
	var stack := _make_stack(25, 0)  # over base cap
	var result := system.is_at_supply_cap(0, [], [stack], 0, _balance)
	assert_true(result, "should be at cap when units > cap")


func test_losing_city_reduces_supply_cap() -> void:
	var system := SupplySystem.new()
	var major := _make_city("major_city", 0)
	var cap_with := system.calculate_supply_cap(0, [major], 0, _balance)
	var cap_without := system.calculate_supply_cap(0, [], 0, _balance)
	assert_gt(cap_with, cap_without, "losing major city reduces cap")


func test_supply_cap_with_mixed_city_tiers() -> void:
	var system := SupplySystem.new()
	var major := _make_city("major_city", 0)
	var village := _make_city("village", 0)
	var hamlet := _make_city("hamlet", 0)
	var cap := system.calculate_supply_cap(0, [major, village, hamlet], 5, _balance)
	# base(20) + major(5) + village(2) + hamlet(2) + floor(5*0.5)=2 = 31
	assert_eq(cap, 31, "mixed cities + territory")


func test_all_supply_values_from_config() -> void:
	var system := SupplySystem.new()
	var supply_config: Dictionary = _balance["supply"]
	assert_eq(int(supply_config["base_cap"]), 20)
	assert_approx(float(supply_config["per_territory_hex"]), 0.5, 0.01)
	assert_eq(int(supply_config["per_major_city"]), 5)
	assert_eq(int(supply_config["per_minor_city"]), 2)
