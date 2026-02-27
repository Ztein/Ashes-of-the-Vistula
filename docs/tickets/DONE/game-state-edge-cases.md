# Game State Edge Cases

## Description
Harden the game state coordinator with edge case handling. Multiple stacks at one city, cascading territory effects, supply cap drops, neutral city capture.

## Systems Affected
- scripts/simulation/game_state.gd (harden)
- tests/integration/test_game_loop.gd (extend)

## Implementation Notes
- Multiple stacks at one city coexist and combine siege damage
- Capturing a city can break enemy territory triangles
- Supply cap drop doesn't destroy units, just blocks production
- Neutral city capture costs one order, no combat needed
- Moving stacks cannot be re-ordered
- Determinism verified over 100-tick replay

## Acceptance Criteria
- [ ] Multiple stacks at one city works correctly
- [ ] Combined siege damage from multiple stacks
- [ ] Territory recalculates on cascading ownership changes
- [ ] Supply cap reduction blocks production without killing units
- [ ] Neutral city capture costs one order, no battle
- [ ] Moving stacks cannot be re-ordered mid-move
- [ ] Simultaneous sieges on different cities
- [ ] Determinism verified over 100 ticks
- [ ] All integration tests pass (~11 additional tests)
