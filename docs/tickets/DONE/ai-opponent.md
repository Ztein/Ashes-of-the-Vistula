# AI Opponent

## Description
Basic AI using the same command queue as the player. Evaluates board state, issues move/siege/capture/consolidation commands.

## Systems Affected
- scripts/ai/ai_controller.gd
- tests/integration/test_ai_behavior.gd

## Implementation Notes
- Uses same command interface as player (no cheating)
- Decision hierarchy: defend → attack → expand → form territory → consolidate
- Evaluates every N ticks (configurable via balance.json)
- Respects order cap and fog of war
- Aggression/defense/territory weights from config

## Acceptance Criteria
- [ ] AI uses the same command queue as the player
- [ ] AI defends cities under siege
- [ ] AI attacks weak enemy cities
- [ ] AI captures neutral cities when nearby
- [ ] AI prioritizes triangle-forming captures
- [ ] AI does not exceed order cap
- [ ] AI respects fog of war
- [ ] AI difficulty adjustable via config
- [ ] Integration tests pass (~8 tests)
