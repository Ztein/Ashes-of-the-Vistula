# Per-Player Stats Display

## Description
Show current game stats for all players, not only the main player. Players should be able to compare their position against opponents at a glance.

## Systems Affected
- scenes/ui/hud.tscn + hud.gd
- scripts/simulation/game_state.gd (read stats for all players)

## Implementation Notes
- Display key stats for each player side-by-side or in a compact panel
- Stats to show per player: city count, territory percentage, unit count/supply, dominance progress
- Could be a toggle panel or always-visible compact summary
- Use player colors to distinguish sides
- Enemy supply/order details may be hidden if fog of war applies — decide based on design intent

## Acceptance Criteria
- [ ] Stats for all players are visible, not just the local player
- [ ] City count shown per player
- [ ] Territory percentage shown per player
- [ ] Unit count / supply usage shown per player
- [ ] Dominance progress shown per player
- [ ] Stats update each simulation tick
