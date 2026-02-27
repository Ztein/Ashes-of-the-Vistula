# Fix Combat Unit Survival Bugs

## Description
Units sometimes survive combat when they should die. Multiple bugs in the damage
application and unit count tracking systems combine to create unkillable or phantom
units, especially visible in multi-stack battles.

## Root Causes

### Bug 1: `ceili()` creates phantom unit counts (CRITICAL)
**File:** `scripts/simulation/unit_stack.gd` lines 57, 70, 81

After damage depletes part of an HP pool, the unit count is recalculated using
`ceili()` (ceiling/round-up). This inflates unit counts beyond what the HP pool
can support.

**Example:** 2 artillery (120 HP total, 60 each). Take 65 damage → HP pool = 55 →
`ceili(55/60) = 1` (ok). But: HP pool = 61 → `ceili(61/60) = 2` → reports 2 units
with only 1.017 units worth of HP. These phantom units contribute full DPS in
`total_dps()` since DPS = `count × dps_per_unit`.

**Fix:** Replace `ceili()` with `maxi(1, floori(...))` or just `ceili()` → consider
that the current approach inflates counts. The correct fix is to use the HP pool
for DPS calculations, or use floor rounding so counts never exceed actual HP.

### Bug 2: Damage only applied to first non-empty stack (CRITICAL)
**File:** `scripts/simulation/combat_resolver.gd` lines 71-78

`_distribute_damage()` applies all incoming damage to the first non-empty stack
then immediately returns. In multi-stack battles, only one stack per side takes
damage each tick. All other stacks are untouched.

Combined with Bug 1, many small stacks accumulate at a city and most take zero
damage per tick while still contributing DPS. This makes large multi-stack armies
nearly unkillable.

**Fix:** Distribute damage across all stacks — either evenly, proportionally to
HP, or with damage spill (kill first stack, spill remainder to next).

### Bug 3: HP pools not initialized for some battle participants (HIGH)
**File:** `scripts/simulation/game_state.gd`

HP pool initialization only happens in two places:
1. Siege→battle transition (line 416-420)
2. Late arrival to active battle (line 390-391)

Stacks that enter combat through other paths (e.g., already present when auto-siege
triggers and siege resolves to battle very quickly) may have unit counts > 0 but
HP pools = 0.0. These stacks:
- Report `is_empty() = false` (checks counts, not HP pools)
- Take no damage (`apply_damage_with_priority` skips pools at 0.0)
- Still contribute DPS via `total_dps()` (uses counts)
- Are never cleaned up (not empty, so `_cleanup_empty_stacks` skips them)

**Fix:** Either always init HP pools before battle ticks, or make `is_empty()`
also check if all HP pools are 0.

## Systems Affected
- `unit_stack.gd` — `apply_damage_with_priority()`, `is_empty()`, `total_dps()`
- `combat_resolver.gd` — `_distribute_damage()`
- `game_state.gd` — HP pool initialization flow

## Acceptance Criteria
- [ ] Unit counts after damage use floor rounding (no phantom units)
- [ ] Battle damage is distributed across all stacks with spill (first stack dies → damage carries to next)
- [ ] All stacks in a battle have HP pools initialized before damage is applied
- [ ] `is_empty()` returns true when all HP pools are 0.0 (even if counts are stale)
- [ ] Multi-stack battles resolve correctly — all defenders die when overwhelmed
- [ ] Single-stack battles still work correctly (no regression)
- [ ] Existing combat tests updated and still pass
- [ ] New tests cover: multi-stack damage spill, phantom unit prevention, zero-HP-pool cleanup
- [ ] Full test suite passes
