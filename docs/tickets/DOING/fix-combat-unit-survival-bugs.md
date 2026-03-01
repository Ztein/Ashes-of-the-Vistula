# Fix Combat Unit Survival Bugs

## Description
Units sometimes survive combat when they should die. Multiple bugs in the damage
application, unit count tracking, and HP pool initialization combine to create
unkillable or phantom units, especially visible in multi-stack battles and longer
games where production accumulates.

## Root Causes

### Bug 1: `ceili()` creates phantom unit counts (CRITICAL)
**File:** `scripts/simulation/unit_stack.gd` line 42

After damage depletes part of an HP pool, the unit count is recalculated using
`ceili()` (ceiling/round-up). This inflates unit counts beyond what the HP pool
can support.

**Example:** 2 artillery (120 HP total, 60 each). Take 59 damage → HP pool = 61 →
`ceili(61/60) = 2` → reports 2 units with only 1.017 units worth of HP. These
phantom units contribute full DPS since `total_dps() = count * dps` and
`total_siege_damage() = count * siege_damage`.

**Fix:** Replace `ceili()` with `floori()`. A unit only counts as alive when it
has a full unit's worth of HP remaining. Alternatively, make `total_dps()` and
`total_siege_damage()` proportional to `hp_pool / hp_each` instead of `count`.

### Bug 2: `_create_stack()` never initializes HP pools (CRITICAL)
**File:** `scripts/simulation/game_state.gd` lines 571-580

`_create_stack()` sets `count = ucount` but never calls `init_hp_pools()`, leaving
`hp_pool = 0.0`. This affects:
- All starting stacks loaded from `scenario.json` (lines 74-81 of `initialize()`)
- All stacks created by `_add_produced_unit()` when no existing same-type stack exists

These stacks have `count > 0` but `hp_pool = 0.0`. When they enter siege-to-battle
transition, `init_hp_pools()` is called and masks the issue. But if they're involved
in auto-merge before that (merging 0.0 + 0.0 = 0.0 HP), the counts are correct but
the HP pool is wrong.

**Fix:** Call `init_hp_pools(balance)` inside `_create_stack()`, or immediately after
every call site.

### Bug 3: `_add_produced_unit()` adds count without HP (CRITICAL)
**File:** `scripts/simulation/game_state.gd` lines 617-624

When adding a unit to an existing stack: `stack.count += 1` but `hp_pool` is NOT
updated. The stack gains a phantom unit that contributes DPS but has no HP backing.

**Fix:** When adding to an existing stack, also add the unit's HP:
```gdscript
var hp_each := float(balance["units"][utype]["hp"])
stack.count += 1
stack.hp_pool += hp_each
```

### Bug 4: `is_empty()` only checks count, not HP pool (HIGH)
**File:** `scripts/simulation/unit_stack.gd` lines 126-127

A stack with `count > 0` but `hp_pool == 0.0` reports `is_empty() == false`. This
means phantom stacks are:
- Not removed by `_cleanup_empty_stacks()` (game_state.gd line 563)
- Included in `_get_player_stacks_at_city()` and used in battle DPS calculations
- Never destroyed, permanently inflating army strength

Combined with Bugs 2-3, these ghost stacks deal DPS but absorb no damage
(`apply_damage` exits early when `hp_pool <= 0.0`), making battles unresolvable.

**Fix:** `is_empty()` should also return true when `hp_pool <= 0.0`:
```gdscript
func is_empty() -> bool:
    return count == 0 or hp_pool <= 0.0
```

### Bug 5: Production continues during siege/battle (MEDIUM)
**File:** `scripts/simulation/game_state.gd` lines 503-521

`_tick_production()` has no check for whether a city is under siege or in active
battle. A defending city produces units mid-combat. These units are added via
`_add_produced_unit()` (Bug 3) without HP, creating unkillable phantom reinforcements
that deal DPS but can't be killed.

**Fix:** Skip production for cities that are in `_sieges` or `_battles`:
```gdscript
if _sieges.has(city.id) or _battles.has(city.id):
    continue
```

## Systems Affected
- `unit_stack.gd` — `apply_damage()`, `is_empty()`, `total_dps()`, `total_siege_damage()`
- `game_state.gd` — `_create_stack()`, `_add_produced_unit()`, `_tick_production()`
- `combat_resolver.gd` — `_distribute_damage()` (indirectly, via phantom stacks)

## Implementation Notes
- Damage spill in `_distribute_damage()` is actually correct — it does carry excess
  damage to the next stack. The previous version of this ticket was wrong about Bug 2.
- The `ceili()` fix (Bug 1) and `is_empty()` fix (Bug 4) together ensure no phantom
  units survive. The HP init fixes (Bugs 2-3) prevent phantom stacks from being created.
- Bug 5 (production during combat) is a design choice — could be intentional. But if
  production continues, the produced units MUST have their HP initialized properly.

## Acceptance Criteria
- [ ] Unit counts after damage use floor rounding (no phantom units from ceili)
- [ ] `_create_stack()` initializes HP pools from balance config
- [ ] `_add_produced_unit()` adds HP when incrementing count on existing stack
- [ ] `is_empty()` returns true when hp_pool <= 0.0 (even if count is stale)
- [ ] Stacks with 0 HP are cleaned up and don't contribute DPS
- [ ] Production during siege/battle either skipped or units properly HP-initialized
- [ ] Multi-stack battles resolve correctly — all defenders die when overwhelmed
- [ ] Single-stack battles still work correctly (no regression)
- [ ] Existing combat tests updated and still pass
- [ ] New tests cover: phantom unit prevention, zero-HP-pool cleanup, production HP init
- [ ] Full test suite passes
