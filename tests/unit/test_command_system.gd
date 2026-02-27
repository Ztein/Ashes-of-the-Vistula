extends BaseTest
## Unit tests for the CommandSystem.

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


# --- Order Cap ---

func test_base_order_cap_from_config() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	var info := system.get_command_info(0)
	assert_eq(info["order_cap"], 3, "base order cap = 3")


func test_major_city_increases_order_cap() -> void:
	var system := CommandSystem.new()
	var major := _make_city("major_city", 0)
	system.initialize_player(0, [major], _balance)
	var info := system.get_command_info(0)
	# base(3) + 1 major * bonus(1) = 4
	assert_eq(info["order_cap"], 4, "major city adds 1 to cap")


# --- Regen Rate ---

func test_base_regen_rate_from_config() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	var info := system.get_command_info(0)
	assert_approx(info["regen_rate"], 0.1, 0.001, "base regen = 0.1")


func test_major_city_increases_regen_rate() -> void:
	var system := CommandSystem.new()
	var major := _make_city("major_city", 0)
	system.initialize_player(0, [major], _balance)
	var info := system.get_command_info(0)
	# base(0.1) + 1 major * bonus(0.05) = 0.15
	assert_approx(info["regen_rate"], 0.15, 0.001, "major city adds regen")


# --- Regeneration ---

func test_orders_regenerate_over_time() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	# Spend some orders first
	system.spend_order(0, 2)
	var info_before := system.get_command_info(0)

	system.tick_regeneration(0, 1.0)  # 1 second

	var info_after := system.get_command_info(0)
	assert_gt(info_after["current_orders"], info_before["current_orders"], "orders should regen")


func test_orders_cannot_exceed_cap() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	# Regen a lot — should still be at cap
	for i in range(100):
		system.tick_regeneration(0, 1.0)
	var info := system.get_command_info(0)
	assert_lte(info["current_orders"], float(info["order_cap"]), "orders should not exceed cap")


# --- Spending ---

func test_spend_order_reduces_pool() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	var before := system.get_command_info(0)["current_orders"] as float
	var success := system.spend_order(0, 1)
	assert_true(success, "spend should succeed")
	var after := system.get_command_info(0)["current_orders"] as float
	assert_approx(after, before - 1.0, 0.01, "pool reduced by 1")


func test_spend_order_fails_when_insufficient() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	# base cap = 3, try to spend 5
	var success := system.spend_order(0, 5)
	assert_false(success, "spend should fail")


func test_can_afford_checks_current_pool() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	assert_true(system.can_afford(0, 2), "should afford 2 of 3")
	assert_false(system.can_afford(0, 4), "should not afford 4 of 3")


# --- City Loss Effects ---

func test_losing_major_city_reduces_cap_and_regen() -> void:
	var system := CommandSystem.new()
	var major := _make_city("major_city", 0)
	system.initialize_player(0, [major], _balance)
	var cap_with := system.get_command_info(0)["order_cap"] as int

	# Recalculate without the major city
	system.recalculate(0, [], _balance)
	var cap_without := system.get_command_info(0)["order_cap"] as int

	assert_gt(cap_with, cap_without, "losing major city reduces cap")


func test_current_orders_clamped_to_new_cap() -> void:
	var system := CommandSystem.new()
	var major1 := _make_city("major_city", 0)
	var major2 := _make_city("major_city", 0)
	major2.id = 1
	system.initialize_player(0, [major1, major2], _balance)
	# cap = 3 + 2 = 5, current starts at 5

	# Lose both major cities, new cap = 3
	system.recalculate(0, [], _balance)
	var info := system.get_command_info(0)
	assert_lte(info["current_orders"], float(info["order_cap"]), "current clamped to new cap")


# --- Config-driven ---

func test_order_costs_loaded_from_config() -> void:
	var costs: Dictionary = _balance["command"]["order_costs"]
	assert_eq(int(costs["move_stack"]), 1)
	assert_eq(int(costs["split_stack"]), 1)
	assert_eq(int(costs["start_siege"]), 1)
	assert_eq(int(costs["capture_neutral"]), 1)


# --- Multi-player ---

func test_multiple_players_have_independent_pools() -> void:
	var system := CommandSystem.new()
	system.initialize_player(0, [], _balance)
	system.initialize_player(1, [], _balance)

	system.spend_order(0, 2)

	var info_0 := system.get_command_info(0)
	var info_1 := system.get_command_info(1)
	assert_lt(info_0["current_orders"], info_1["current_orders"], "player 0 spent, player 1 didn't")
