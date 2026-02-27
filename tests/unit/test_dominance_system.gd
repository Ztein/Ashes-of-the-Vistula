extends BaseTest
## Unit tests for the DominanceSystem.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


# --- Thresholds ---

func test_dominance_not_triggered_below_city_threshold() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	# 60% of 15 = 9 cities needed. Have 5.
	var result := system.tick(0, 0.1, 5, 15, 150, 200, _balance)
	assert_false(result["is_dominant"], "below city threshold")


func test_dominance_not_triggered_below_territory_threshold() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	# 50% of 200 = 100 hexes needed. Have 50.
	var result := system.tick(0, 0.1, 12, 15, 50, 200, _balance)
	assert_false(result["is_dominant"], "below territory threshold")


func test_dominance_not_triggered_when_only_city_threshold_met() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	# Cities: 12/15 = 80% >= 60%. Territory: 30/200 = 15% < 50%.
	var result := system.tick(0, 0.1, 12, 15, 30, 200, _balance)
	assert_false(result["is_dominant"], "only city threshold met")


func test_dominance_triggered_when_both_thresholds_met() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	# Cities: 12/15 = 80% >= 60%. Territory: 120/200 = 60% >= 50%.
	var result := system.tick(0, 0.1, 12, 15, 120, 200, _balance)
	assert_true(result["is_dominant"], "both thresholds met")


# --- Timer ---

func test_dominance_timer_counts_down_while_dominant() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	# timer_duration = 120.0
	var result := system.tick(0, 1.0, 12, 15, 120, 200, _balance)
	assert_lt(result["timer_remaining"], 120.0, "timer should count down")


func test_dominance_victory_when_timer_reaches_zero() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	# Tick dominance for the full duration
	var victory := false
	for i in range(1300):  # 1300 * 0.1 = 130 seconds > 120 duration
		var result := system.tick(0, 0.1, 12, 15, 120, 200, _balance)
		if result.get("victory", false):
			victory = true
			break
	assert_true(victory, "should achieve victory after timer expires")


func test_dominance_timer_resets_when_city_threshold_lost() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)

	# Start dominating
	system.tick(0, 5.0, 12, 15, 120, 200, _balance)
	var result_during := system.tick(0, 0.0, 12, 15, 120, 200, _balance)
	assert_true(result_during["is_dominant"], "should be dominant")

	# Lose city threshold
	var result_after := system.tick(0, 0.1, 5, 15, 120, 200, _balance)
	assert_false(result_after["is_dominant"], "should not be dominant")
	assert_approx(result_after["timer_remaining"], 120.0, 0.01, "timer should reset")


func test_dominance_timer_resets_when_territory_threshold_lost() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)

	# Start dominating
	system.tick(0, 5.0, 12, 15, 120, 200, _balance)

	# Lose territory threshold
	var result := system.tick(0, 0.1, 12, 15, 30, 200, _balance)
	assert_false(result["is_dominant"], "should not be dominant")
	assert_approx(result["timer_remaining"], 120.0, 0.01, "timer should reset")


# --- Config ---

func test_dominance_thresholds_from_config() -> void:
	var dom_config: Dictionary = _balance["dominance"]
	assert_eq(int(dom_config["city_threshold_pct"]), 60)
	assert_eq(int(dom_config["territory_threshold_pct"]), 50)


func test_dominance_timer_duration_from_config() -> void:
	var dom_config: Dictionary = _balance["dominance"]
	assert_approx(float(dom_config["timer_duration"]), 120.0, 0.01)


func test_multiple_players_tracked_independently() -> void:
	var system := DominanceSystem.new()
	system.initialize_player(0, _balance)
	system.initialize_player(1, _balance)

	# Player 0 dominates, player 1 does not
	system.tick(0, 1.0, 12, 15, 120, 200, _balance)
	system.tick(1, 1.0, 3, 15, 20, 200, _balance)

	var r0 := system.tick(0, 0.0, 12, 15, 120, 200, _balance)
	var r1 := system.tick(1, 0.0, 3, 15, 20, 200, _balance)

	assert_true(r0["is_dominant"], "player 0 dominant")
	assert_false(r1["is_dominant"], "player 1 not dominant")
