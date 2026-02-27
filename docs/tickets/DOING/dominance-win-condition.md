# Dominance Win Condition

## Description
Dominance timer: control X% of cities AND Y% of territory hexes → countdown begins → maintain for duration → victory. Timer resets when thresholds lost.

## Systems Affected
- scripts/simulation/dominance_system.gd
- tests/unit/test_dominance_system.gd

## Implementation Notes
- Per-player: is_dominant (bool), timer_remaining (float)
- check_thresholds: city_pct >= threshold AND territory_pct >= threshold
- Timer counts down while dominant
- Victory when timer reaches 0
- Timer resets to full when either threshold drops

## Acceptance Criteria
- [ ] Triggers when city% ≥ threshold AND territory% ≥ threshold
- [ ] Timer counts down while dominant
- [ ] Victory at timer 0
- [ ] Timer resets when either threshold lost
- [ ] Thresholds and duration from balance.json
- [ ] Independent per player
- [ ] All unit tests pass (~11 tests)
