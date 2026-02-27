# Combat Visuals

## Description
Render siege progress (HP bar on city), battle resolution (damage exchange), and capture effects (color change).

## Systems Affected
- scripts/presentation/combat_renderer.gd
- scenes/combat/siege_display.tscn
- scenes/combat/battle_display.tscn

## Implementation Notes
- Siege: structure HP bar decreasing on besieged cities
- Battle: visual indicator of both sides taking damage
- Capture: city color changes on ownership flip
- All driven by simulation signals

## Acceptance Criteria
- [ ] Siege shows structure HP bar decreasing
- [ ] Battle shows both sides taking damage
- [ ] City color changes on capture
- [ ] Combat state clearly indicated visually
- [ ] All driven by simulation signals
