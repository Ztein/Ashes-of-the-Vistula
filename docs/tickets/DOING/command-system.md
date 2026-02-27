# Command System

## Description
Order pool with cap and regeneration. Orders spent on actions (move, split, siege, capture). Major cities boost cap and regen rate.

## Systems Affected
- scripts/simulation/command_system.gd
- tests/unit/test_command_system.gd

## Implementation Notes
- Per-player state: current orders (float), cap (int), regen rate (float)
- Cap = base_order_cap + major_city_cap_bonus × major_cities_owned
- Regen = base_regen_rate + major_city_regen_bonus × major_cities_owned
- tick_regeneration: current += regen × delta, clamped to cap
- spend_order: deduct if affordable, return success
- Recalculate on city ownership changes

## Acceptance Criteria
- [ ] Cap = base + major_city bonus per owned major city
- [ ] Regen = base + major_city regen bonus per owned major city
- [ ] Orders regenerate per tick, clamped to cap
- [ ] Spending deducts from pool, fails if insufficient
- [ ] Losing major city reduces cap and regen; current clamped
- [ ] Independent pools per player
- [ ] Order costs from balance.json
- [ ] All unit tests pass (~14 tests)
