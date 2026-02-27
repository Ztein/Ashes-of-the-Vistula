# Supply System

## Description
Global supply cap calculated from base + city bonuses + territory hex bonuses. Each unit consumes 1 supply. Production halts when cap reached.

## Systems Affected
- scripts/simulation/supply_system.gd
- tests/unit/test_supply_system.gd

## Implementation Notes
- Formula: base_cap + (major_cities × per_major_city) + (minor_cities × per_minor_city) + floor(territory_hexes × per_territory_hex)
- Minor cities = hamlets + villages
- Current supply = total unit count across all stacks for a player
- Expose supply info dictionary: { current, cap, available }

## Acceptance Criteria
- [ ] Cap = base + city bonuses + territory bonuses
- [ ] Major cities contribute per_major_city; minor cities per_minor_city
- [ ] Territory hexes contribute at per_territory_hex rate
- [ ] Current supply = total unit count
- [ ] Cap detection works correctly
- [ ] All values from config
- [ ] All unit tests pass (~11 tests)
