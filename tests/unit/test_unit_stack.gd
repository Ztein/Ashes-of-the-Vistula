extends BaseTest
## Unit tests for the UnitStack simulation class (homogeneous stacks).

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_stack(utype: String = "infantry", ucount: int = 5, owner: int = 0, city: int = 0) -> UnitStack:
	var stack := UnitStack.new()
	stack.id = 1
	stack.owner_id = owner
	stack.city_id = city
	stack.unit_type = utype
	stack.count = ucount
	return stack


# --- Total Units ---

func test_stack_total_units_returns_count() -> void:
	var stack := _make_stack("infantry", 6)
	assert_eq(stack.total_units(), 6, "6 infantry = 6 total")


func test_stack_total_units_zero() -> void:
	var stack := _make_stack("infantry", 0)
	assert_eq(stack.total_units(), 0, "empty stack = 0 total")


# --- Config-driven DPS ---

func test_stack_total_dps_uses_config_values() -> void:
	var stack := _make_stack("infantry", 3)
	stack.init_hp_pools(_balance)  # 300 HP, proportional DPS = (300/100)*10 = 30
	assert_approx(stack.total_dps(_balance), 30.0, 0.01, "DPS should use config values")


func test_stack_total_dps_cavalry() -> void:
	var stack := _make_stack("cavalry", 2)
	stack.init_hp_pools(_balance)  # 160 HP, proportional DPS = (160/80)*15 = 30
	assert_approx(stack.total_dps(_balance), 30.0, 0.01, "cavalry DPS")


func test_stack_total_siege_damage_uses_config() -> void:
	var stack := _make_stack("artillery", 2)
	stack.init_hp_pools(_balance)  # 120 HP, proportional siege = (120/60)*20 = 40
	assert_approx(stack.total_siege_damage(_balance), 40.0, 0.01, "siege damage from config")


# --- Movement Speed ---

func test_stack_speed_infantry() -> void:
	var stack := _make_stack("infantry", 5)
	assert_approx(stack.movement_speed(_balance), 1.0, 0.01, "infantry speed = 1.0")


func test_stack_speed_cavalry() -> void:
	var stack := _make_stack("cavalry", 3)
	assert_approx(stack.movement_speed(_balance), 1.5, 0.01, "cavalry speed = 1.5")


func test_stack_speed_artillery() -> void:
	var stack := _make_stack("artillery", 2)
	assert_approx(stack.movement_speed(_balance), 0.6, 0.01, "artillery speed = 0.6")


func test_stack_speed_empty_is_zero() -> void:
	var stack := _make_stack("infantry", 0)
	assert_approx(stack.movement_speed(_balance), 0.0, 0.01, "empty stack speed = 0")


# --- Split Half ---

func test_stack_split_half_even() -> void:
	var stack := _make_stack("infantry", 6)
	var new_stack := stack.split_half()
	assert_not_null(new_stack, "split should return a new stack")
	assert_eq(new_stack.count, 3, "new stack gets floor(6/2) = 3")
	assert_eq(stack.count, 3, "original keeps ceil(6/2) = 3")


func test_stack_split_half_odd() -> void:
	var stack := _make_stack("infantry", 5)
	var new_stack := stack.split_half()
	assert_not_null(new_stack, "split should return a new stack")
	assert_eq(new_stack.count, 2, "new stack gets floor(5/2) = 2")
	assert_eq(stack.count, 3, "original keeps 5 - 2 = 3")


func test_stack_split_half_returns_null_for_single_unit() -> void:
	var stack := _make_stack("infantry", 1)
	var new_stack := stack.split_half()
	assert_null(new_stack, "can't split single unit")


func test_stack_split_half_preserves_type() -> void:
	var stack := _make_stack("cavalry", 4, 1, 5)
	var new_stack := stack.split_half()
	assert_not_null(new_stack)
	assert_eq(new_stack.unit_type, "cavalry", "new stack same type")
	assert_eq(new_stack.owner_id, 1, "inherits owner")
	assert_eq(new_stack.city_id, 5, "inherits city")


func test_stack_split_half_distributes_hp_proportionally() -> void:
	var stack := _make_stack("infantry", 4)
	stack.init_hp_pools(_balance)  # 4 * 100 = 400 HP
	var new_stack := stack.split_half()
	assert_not_null(new_stack)
	assert_approx(stack.hp_pool + new_stack.hp_pool, 400.0, 0.01, "total HP preserved")
	assert_gt(new_stack.hp_pool, 0.0, "new stack has HP")


# --- Merge ---

func test_stack_merge_combines_same_type() -> void:
	var stack_a := _make_stack("infantry", 3, 0, 5)
	var stack_b := _make_stack("infantry", 2, 0, 5)
	var result := stack_a.merge(stack_b)
	assert_true(result, "merge should succeed")
	assert_eq(stack_a.count, 5, "3 + 2 = 5")


func test_stack_merge_fails_different_types() -> void:
	var stack_a := _make_stack("infantry", 3, 0, 5)
	var stack_b := _make_stack("cavalry", 2, 0, 5)
	var result := stack_a.merge(stack_b)
	assert_false(result, "different types should not merge")


func test_stack_merge_fails_different_owners() -> void:
	var stack_a := _make_stack("infantry", 3, 0, 5)
	var stack_b := _make_stack("infantry", 2, 1, 5)
	var result := stack_a.merge(stack_b)
	assert_false(result, "different owners should not merge")


func test_stack_merge_fails_different_cities() -> void:
	var stack_a := _make_stack("infantry", 3, 0, 5)
	var stack_b := _make_stack("infantry", 2, 0, 6)
	var result := stack_a.merge(stack_b)
	assert_false(result, "different cities should not merge")


func test_stack_merge_combines_hp_pools() -> void:
	var stack_a := _make_stack("infantry", 3, 0, 5)
	stack_a.init_hp_pools(_balance)  # 300
	var stack_b := _make_stack("infantry", 2, 0, 5)
	stack_b.init_hp_pools(_balance)  # 200
	stack_a.merge(stack_b)
	assert_approx(stack_a.hp_pool, 500.0, 0.01, "HP pools combined")


# --- Movement ---

func test_stack_move_progress_advances_per_tick() -> void:
	var stack := _make_stack("infantry", 3)
	stack.start_move(2)
	assert_true(stack.is_moving, "stack should be moving")
	var arrived := stack.tick_move(0.1, 1.0)
	assert_false(arrived, "should not have arrived yet")
	assert_gt(stack.move_progress, 0.0, "progress should advance")


func test_stack_move_completes_at_full_progress() -> void:
	var stack := _make_stack("infantry", 3)
	stack.start_move(2)
	var arrived := stack.tick_move(1.0, 1.0)
	assert_true(arrived, "should arrive after sufficient movement")
	assert_false(stack.is_moving, "should no longer be moving")
	assert_eq(stack.city_id, 2, "should be at target city")


# --- Damage ---

func test_stack_apply_damage_reduces_hp() -> void:
	var stack := _make_stack("infantry", 5)
	stack.init_hp_pools(_balance)  # 500 HP
	stack.apply_damage(100.0, _balance)
	assert_approx(stack.hp_pool, 400.0, 0.01, "HP reduced by damage")
	assert_eq(stack.count, 4, "floor(400/100) = 4 units remaining")


func test_stack_apply_damage_eliminates_when_hp_depleted() -> void:
	var stack := _make_stack("infantry", 2)
	stack.init_hp_pools(_balance)  # 200 HP
	stack.apply_damage(300.0, _balance)
	assert_eq(stack.count, 0, "all units eliminated")
	assert_approx(stack.hp_pool, 0.0, 0.01, "HP is 0")


# --- Is Empty ---

func test_stack_is_empty_when_count_zero() -> void:
	var stack := _make_stack("infantry", 0)
	assert_true(stack.is_empty(), "stack with 0 units is empty")


func test_stack_is_not_empty_with_units() -> void:
	var stack := _make_stack("infantry", 1)
	stack.init_hp_pools(_balance)
	assert_false(stack.is_empty(), "stack with units and HP is not empty")


# --- Bug Fix: ceili phantom unit prevention ---

func test_apply_damage_phantom_dps_prevented_by_hp_proportional() -> void:
	# Bug 1: ceili() inflates count, but DPS is now HP-proportional so it doesn't matter.
	# 2 artillery (60 HP each) = 120 HP. Take 59 damage → 61 HP.
	# ceili(61/60) = 2 (count), but DPS = (61/60)*5 = 5.08, not 2*5 = 10.
	var stack := _make_stack("artillery", 2)
	stack.init_hp_pools(_balance)  # 120 HP
	stack.apply_damage(59.0, _balance)
	assert_approx(stack.hp_pool, 61.0, 0.01, "HP = 120 - 59 = 61")
	# DPS should be proportional to HP, not inflated by count
	var expected_dps: float = (61.0 / 60.0) * 5.0
	assert_approx(stack.total_dps(_balance), expected_dps, 0.01, "DPS proportional to HP, not count")


func test_apply_damage_exact_unit_boundary_keeps_correct_count() -> void:
	# When HP is exactly on a unit boundary, count should be correct
	var stack := _make_stack("infantry", 3)
	stack.init_hp_pools(_balance)  # 300 HP
	stack.apply_damage(100.0, _balance)  # 200 HP remaining = exactly 2 units
	assert_eq(stack.count, 2, "exactly 2 units worth of HP = 2 count")


func test_zero_hp_pool_stack_deals_no_dps() -> void:
	# A stack with hp_pool=0 must deal 0 DPS regardless of count
	var stack := _make_stack("infantry", 5)
	# Don't init HP — hp_pool stays 0.0
	assert_approx(stack.total_dps(_balance), 0.0, 0.01, "zero HP pool = zero DPS")
	assert_approx(stack.total_siege_damage(_balance), 0.0, 0.01, "zero HP pool = zero siege")


# --- Bug Fix: is_empty() checks HP pool ---

func test_is_empty_true_when_hp_pool_zero_but_count_stale() -> void:
	# Bug 4: is_empty() only checks count. A stack with count>0 but hp_pool=0
	# should be considered empty.
	var stack := _make_stack("infantry", 3)
	# Don't init HP pools — simulates the bug where hp_pool stays 0
	assert_true(stack.is_empty(), "stack with count > 0 but hp_pool = 0 should be empty")
