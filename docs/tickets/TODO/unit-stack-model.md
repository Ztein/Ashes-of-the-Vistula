# Unit Stack Model

## Description
Implement UnitStack — armies represented as composition counts (infantry/cavalry/artillery). Supports split, merge, movement, casualties.

## Systems Affected
- scripts/simulation/unit_stack.gd
- tests/unit/test_unit_stack.gd

## Implementation Notes
- Extends RefCounted (pure simulation)
- Properties: id, owner_id, city_id, infantry/cavalry/artillery counts, movement state (is_moving, move_target, move_progress)
- Computed: total_units, total_dps, total_siege_damage, movement_speed (slowest unit)
- Operations: split, merge, start_move, tick_move, take_casualties, add_units
- Speed = minimum speed of any unit type present in the stack

## Acceptance Criteria
- [ ] Stack stores and exposes infantry/cavalry/artillery counts
- [ ] DPS and siege damage calculated from config
- [ ] Speed = minimum speed of any unit type present
- [ ] Split creates new stack, reduces original, validates sufficiency
- [ ] Merge combines stacks, validates same owner and city
- [ ] Movement progress tracks correctly, reports arrival
- [ ] Casualties reduce counts clamped to 0
- [ ] All config-driven, no hardcoded numbers
- [ ] All unit tests pass (~18 tests)
