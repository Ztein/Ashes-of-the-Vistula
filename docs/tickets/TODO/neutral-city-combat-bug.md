# Neutral City Combat Bug

## Description
When two opposing units (stacks from different players) are in the same neutral city, combat does not trigger. The auto-siege system skips neutral cities entirely, meaning enemy stacks can coexist peacefully at a neutral city without any siege or battle starting.

## Root Cause (Suspected)
In `game_state.gd`, the `_auto_start_sieges()` method has an early return for neutral cities:
```gdscript
if city.owner_id < 0: continue
```
This means when both Player 0 and Player 1 have stacks at a neutral city, no siege/battle is initiated.

## Expected Behavior
When stacks from two different players are at the same city — regardless of whether it's owned, enemy, or neutral — combat should trigger. For neutral cities, this could be:
- A direct battle (no siege phase, since neutral cities have no allegiance to defend)
- Or a siege against the neutral city's structure HP, followed by battle

## Systems Affected
- `scripts/simulation/game_state.gd` — `_auto_start_sieges()` method

## Acceptance Criteria
- [ ] Opposing stacks at a neutral city trigger combat
- [ ] Combat resolution works correctly at neutral cities
- [ ] City ownership transfers correctly after combat at neutral city
- [ ] Unit tests cover neutral city combat scenarios
- [ ] Integration test: two opposing stacks arrive at neutral city → combat → winner captures
- [ ] Existing siege/battle tests still pass
