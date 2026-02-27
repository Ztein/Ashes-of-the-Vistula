extends BaseTest
## Unit tests for the UnitStack simulation class.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_stack(inf: int = 3, cav: int = 2, art: int = 1, owner: int = 0, city: int = 0) -> UnitStack:
	var stack := UnitStack.new()
	stack.id = 1
	stack.owner_id = owner
	stack.city_id = city
	stack.infantry_count = inf
	stack.cavalry_count = cav
	stack.artillery_count = art
	return stack


# --- Total Units ---

func test_stack_total_units_sums_all_types() -> void:
	var stack := _make_stack(3, 2, 1)
	assert_eq(stack.total_units(), 6, "3 inf + 2 cav + 1 art = 6")


func test_stack_total_units_with_zero_types() -> void:
	var stack := _make_stack(5, 0, 0)
	assert_eq(stack.total_units(), 5, "5 inf only = 5")


# --- Config-driven DPS ---

func test_stack_total_dps_uses_config_values() -> void:
	var stack := _make_stack(3, 2, 1)
	# infantry dps=10, cavalry dps=15, artillery dps=5
	# 3*10 + 2*15 + 1*5 = 30 + 30 + 5 = 65
	var expected := 3.0 * 10 + 2.0 * 15 + 1.0 * 5
	assert_approx(stack.total_dps(_balance), expected, 0.01, "DPS should use config values")


func test_stack_total_siege_damage_uses_config() -> void:
	var stack := _make_stack(3, 2, 1)
	# infantry siege=5, cavalry siege=2, artillery siege=20
	# 3*5 + 2*2 + 1*20 = 15 + 4 + 20 = 39
	var expected := 3.0 * 5 + 2.0 * 2 + 1.0 * 20
	assert_approx(stack.total_siege_damage(_balance), expected, 0.01, "siege damage from config")


# --- Movement Speed ---

func test_stack_speed_limited_by_slowest_unit() -> void:
	var stack := _make_stack(1, 1, 1)
	# infantry speed=1.0, cavalry speed=1.5, artillery speed=0.6
	# slowest = artillery = 0.6
	assert_approx(stack.movement_speed(_balance), 0.6, 0.01, "speed limited by artillery")


func test_stack_speed_infantry_only() -> void:
	var stack := _make_stack(5, 0, 0)
	assert_approx(stack.movement_speed(_balance), 1.0, 0.01, "infantry-only speed = 1.0")


func test_stack_speed_cavalry_only() -> void:
	var stack := _make_stack(0, 3, 0)
	assert_approx(stack.movement_speed(_balance), 1.5, 0.01, "cavalry-only speed = 1.5")


# --- Split ---

func test_stack_split_creates_new_stack_with_correct_counts() -> void:
	var stack := _make_stack(4, 2, 2)
	var new_stack := stack.split(2, 1, 1)
	assert_not_null(new_stack, "split should return a new stack")
	assert_eq(new_stack.infantry_count, 2)
	assert_eq(new_stack.cavalry_count, 1)
	assert_eq(new_stack.artillery_count, 1)


func test_stack_split_removes_units_from_original() -> void:
	var stack := _make_stack(4, 2, 2)
	stack.split(2, 1, 1)
	assert_eq(stack.infantry_count, 2, "original infantry reduced")
	assert_eq(stack.cavalry_count, 1, "original cavalry reduced")
	assert_eq(stack.artillery_count, 1, "original artillery reduced")


func test_stack_split_returns_null_if_insufficient() -> void:
	var stack := _make_stack(2, 1, 0)
	var new_stack := stack.split(3, 0, 0)
	assert_null(new_stack, "should return null when not enough infantry")


func test_stack_split_preserves_owner_and_city() -> void:
	var stack := _make_stack(4, 2, 0, 1, 5)
	var new_stack := stack.split(2, 1, 0)
	assert_not_null(new_stack)
	assert_eq(new_stack.owner_id, 1, "new stack inherits owner")
	assert_eq(new_stack.city_id, 5, "new stack inherits city")


# --- Merge ---

func test_stack_merge_combines_units() -> void:
	var stack_a := _make_stack(3, 2, 1, 0, 5)
	var stack_b := _make_stack(2, 1, 0, 0, 5)
	var result := stack_a.merge(stack_b)
	assert_true(result, "merge should succeed")
	assert_eq(stack_a.infantry_count, 5)
	assert_eq(stack_a.cavalry_count, 3)
	assert_eq(stack_a.artillery_count, 1)


func test_stack_merge_fails_different_owners() -> void:
	var stack_a := _make_stack(3, 0, 0, 0, 5)
	var stack_b := _make_stack(2, 0, 0, 1, 5)
	var result := stack_a.merge(stack_b)
	assert_false(result, "merge should fail with different owners")


func test_stack_merge_fails_different_cities() -> void:
	var stack_a := _make_stack(3, 0, 0, 0, 5)
	var stack_b := _make_stack(2, 0, 0, 0, 6)
	var result := stack_a.merge(stack_b)
	assert_false(result, "merge should fail at different cities")


# --- Movement ---

func test_stack_move_progress_advances_per_tick() -> void:
	var stack := _make_stack(3, 0, 0)
	stack.start_move(2)
	assert_true(stack.is_moving, "stack should be moving")
	# infantry speed = 1.0, delta = 0.1 => progress += 0.1
	var arrived := stack.tick_move(0.1, 1.0)
	assert_false(arrived, "should not have arrived yet")
	assert_gt(stack.move_progress, 0.0, "progress should advance")


func test_stack_move_completes_at_full_progress() -> void:
	var stack := _make_stack(3, 0, 0)
	stack.start_move(2)
	# Move in one big step
	var arrived := stack.tick_move(1.0, 1.0)
	assert_true(arrived, "should arrive after sufficient movement")
	assert_false(stack.is_moving, "should no longer be moving")
	assert_eq(stack.city_id, 2, "should be at target city")


# --- Casualties ---

func test_stack_casualties_reduce_counts() -> void:
	var stack := _make_stack(5, 3, 2)
	stack.take_casualties(2, 1, 1)
	assert_eq(stack.infantry_count, 3)
	assert_eq(stack.cavalry_count, 2)
	assert_eq(stack.artillery_count, 1)


func test_stack_casualties_clamp_to_zero() -> void:
	var stack := _make_stack(2, 1, 0)
	stack.take_casualties(5, 3, 1)
	assert_eq(stack.infantry_count, 0, "clamped to 0")
	assert_eq(stack.cavalry_count, 0, "clamped to 0")
	assert_eq(stack.artillery_count, 0, "clamped to 0")


func test_stack_is_empty_when_all_zero() -> void:
	var stack := _make_stack(0, 0, 0)
	assert_true(stack.is_empty(), "stack with no units is empty")


func test_stack_is_not_empty_with_units() -> void:
	var stack := _make_stack(1, 0, 0)
	assert_false(stack.is_empty(), "stack with units is not empty")


# --- Add Units ---

func test_stack_add_units_increases_counts() -> void:
	var stack := _make_stack(2, 1, 0)
	stack.add_units(1, 2, 1)
	assert_eq(stack.infantry_count, 3)
	assert_eq(stack.cavalry_count, 3)
	assert_eq(stack.artillery_count, 1)
