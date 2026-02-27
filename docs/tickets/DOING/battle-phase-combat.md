# Battle Phase Combat

## Description
Implement the battle phase. Both sides deal DPS simultaneously with priority targeting (Artillery → Cavalry → Infantry). Deterministic resolution. City flips on defender elimination.

## Systems Affected
- scripts/simulation/combat_resolver.gd (extend)
- tests/unit/test_combat_resolver.gd (extend)

## Implementation Notes
- Simultaneous DPS exchange each battle tick
- Priority targeting: Artillery → Cavalry → Infantry
- HP pools per unit type; damage spills to next type when depleted
- City flips on defender elimination, structure HP resets
- Must be fully deterministic

## Acceptance Criteria
- [ ] Simultaneous DPS exchange each battle tick
- [ ] Priority targeting: Artillery → Cavalry → Infantry
- [ ] Damage spills to next type when one is eliminated
- [ ] City flips on defender elimination
- [ ] Structure HP resets on capture
- [ ] Fully deterministic (same inputs → same outputs)
- [ ] All values from config
- [ ] Unit tests cover all criteria (~11 tests)
