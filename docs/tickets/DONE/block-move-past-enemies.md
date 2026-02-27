# Block Movement Past Enemy Stacks

## Description
Add a rule that stacks cannot move out of a city where enemy stacks are present. Enemies at a city pin your forces in place — you must fight or wait for the enemy to leave before moving on.

## Systems Affected
- scripts/simulation/game_state.gd (`_cmd_move` validation)
- scripts/ai/ai_controller.gd (AI must account for pinning)
- tests/unit/test_game_loop.gd or new test file

## Implementation Notes
- In `_cmd_move`, before allowing movement, check if any enemy (non-moving) stacks are present at the stack's current city
- If enemy stacks are present at the origin city, reject the move command
- This creates a "pinning" mechanic: moving into a contested city locks both sides until one is destroyed or retreats via other means
- The AI should be aware of this rule when evaluating moves

## Acceptance Criteria
- [ ] Move command is rejected when enemy stacks are present at the origin city
- [ ] Stacks can still move freely from cities with only friendly or no stacks
- [ ] AI accounts for the pinning rule in its move evaluation
- [ ] Unit tests cover: move blocked by enemy, move allowed without enemy, move allowed after enemy leaves
