# Game State Coordinator

## Description
Top-level GameState that owns all simulation systems, processes a command queue, advances all systems per tick, and emits signals for state changes.

## Systems Affected
- scripts/simulation/game_state.gd
- tests/integration/test_game_loop.gd

## Implementation Notes
- Owns: cities, stacks, combat_resolver, supply_system, command_system, territory_system, dominance_system
- Command queue: MOVE_STACK, SPLIT_STACK, START_SIEGE, CAPTURE_NEUTRAL
- submit_command validates adjacency, ownership, order affordability
- tick() loop: process commands → movement → sieges → battles → production → orders → territory → dominance → signals
- Deterministic: same commands in same order = identical state

## Acceptance Criteria
- [ ] Initializes from all three JSON data sources
- [ ] Command queue validates and processes commands
- [ ] Commands spend orders
- [ ] Tick advances all systems in correct order
- [ ] Siege → battle → capture works end-to-end
- [ ] Production, supply, orders, territory, dominance all work together
- [ ] Signals emitted for all state changes
- [ ] Deterministic: same commands = identical state
- [ ] All integration tests pass (~14 tests)
