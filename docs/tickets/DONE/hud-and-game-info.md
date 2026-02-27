# HUD and Game Info

## Description
HUD showing supply, orders, dominance timer, city count, territory percentage. Fog of war overlay hiding non-visible areas and enemy units.

## Systems Affected
- scenes/ui/hud.tscn + hud.gd
- scripts/presentation/fog_renderer.gd

## Implementation Notes
- Supply: "Units: 12/25"
- Orders: "Orders: 2.3/4" with regen indicator
- Dominance: timer or "Not active"
- Cities: "Cities: 8/15"
- Territory: "Territory: 42%"
- Fog: non-visible hexes dimmed, enemy stacks hidden in fog
- Territory and city adjacency provide vision

## Acceptance Criteria
- [ ] All HUD elements display correct values
- [ ] Values update each simulation tick
- [ ] Fog of war dims non-visible areas
- [ ] Enemy units hidden in fog
