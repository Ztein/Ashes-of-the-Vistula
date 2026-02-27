# Siege Phase Combat

## Description
Implement the siege phase where attackers damage structure HP. Defenders cannot be damaged during siege. Structure regenerates if attackers retreat. Siege ends when structure HP reaches 0.

## Systems Affected
- scripts/simulation/combat_resolver.gd
- tests/unit/test_combat_resolver.gd

## Implementation Notes
- Siege damage per tick = sum of all attacking stacks' total_siege_damage
- Multiple stacks can combine siege damage
- Structure regen rate from balance.json per city tier
- No regen during active siege
- Transition to battle at structure HP 0

## Acceptance Criteria
- [ ] Attacking stack reduces city structure HP by total siege damage per tick
- [ ] Multiple stacks combine siege damage
- [ ] Defenders take zero damage during siege phase
- [ ] Structure HP regenerates when no attackers present
- [ ] Structure HP stops regenerating while under active siege
- [ ] Siege → battle transition triggers at structure HP 0
- [ ] All behavior driven by balance.json values
- [ ] Unit tests cover all criteria (~10 tests)
