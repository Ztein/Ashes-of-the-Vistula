# Investigate: Cannot Issue Orders After Combat Fix

## Description
After the combat unit survival bug fix (HP-proportional DPS, `is_empty()` check on
hp_pool, production halted during combat), players report being unable to issue orders.
Exact symptoms unclear — could be inability to select stacks, commands being rejected,
or stacks being pinned by combat.

## Investigation Results

### Code audit: no direct bug found in command path
The command processing (`_cmd_move`, `_cmd_split`, `_cmd_start_siege`, `_cmd_capture_neutral`)
does NOT use `is_empty()`. The `submit_command()` → `_cmd_move()` flow checks:
1. Stack exists in `_stacks`
2. Stack owned by player
3. Stack not moving
4. Cities adjacent
5. No enemy stacks pinning (`_has_enemy_stacks_at_city` — uses `is_empty()`)
6. Can afford order cost

Initialization is correct: `_balance` is set (line 49) before `_create_stack()` is
called (lines 75-81), so all stacks get proper HP pools.

### Potential cause 1: `_get_player_stacks_at_city()` includes dead stacks
**File:** `scripts/simulation/game_state.gd` line 602-608

The private `_get_player_stacks_at_city()` does NOT filter by `is_empty()`. It's used in:
- `_tick_sieges()` — to get attacker stacks
- `_tick_battles()` — to get attacker and defender stacks
- `_add_produced_unit()` — to find existing stacks

If dead stacks (hp_pool=0, count=0) exist before cleanup runs (end of tick), the arrays
returned are non-empty. `_tick_battles()` checks `attacker_stacks.is_empty()` (array check,
not unit check) and proceeds to run `tick_battle()` on dead stacks. This could:
- Keep siege/battle state active longer than it should
- Cause incorrect city captures (both sides dead → attacker wins by check order)
- Prevent siege cleanup, leaving `_sieges` entry → blocks production at that city

**Fix:** Filter by `is_empty()` in `_get_player_stacks_at_city()`:
```gdscript
if s.owner_id == player_id and s.city_id == city_id and not s.is_moving and not s.is_empty():
```

### Potential cause 2: Stale siege/battle state blocks production everywhere
With production halted during siege/battle (`_tick_production` skips cities in `_sieges`
or `_battles`), if a siege never gets cleaned up (because `_get_player_stacks_at_city`
returns phantom stacks making the array non-empty), production at that city is permanently
blocked. Over time, the player runs out of units.

### Potential cause 3: Balance shift from HP-proportional DPS
DPS is now proportional to `hp_pool / hp_each` instead of `count`. At full HP, output is
identical. But during battle, as stacks take damage, they deal progressively less damage.
This makes battles take longer, keeping stacks pinned longer. Combined with halted
production, this could make it feel impossible to issue orders because:
- Stacks are pinned at besieged cities (can't move out with enemy present)
- Battles take longer to resolve
- No reinforcements produced at besieged cities
- Player runs out of available orders or available stacks

### Potential cause 4: Selected stack cleaned up mid-interaction
If a player selects a stack (stored as `_selected_stack_id`), then that stack gets
destroyed in combat and cleaned up, the stored ID points to a deleted stack. The next
city click tries to issue a move for a non-existent stack (silently fails), then falls
through to the re-selection logic. This makes the first click after a stack dies seem
unresponsive.

## Systems Affected
- `game_state.gd` — `_get_player_stacks_at_city()`, `_tick_battles()`, `_tick_sieges()`
- `game.gd` — stack selection with stale `_selected_stack_id`
- `unit_stack.gd` — `is_empty()` behavior change

## Acceptance Criteria
- [x] `_get_player_stacks_at_city()` filters out empty stacks
- [x] Siege/battle state is correctly cleaned up when all combatants die
- [x] Selected stack reference is cleared when the stack is destroyed
- [x] Player can select and move stacks under normal conditions
- [x] Production halted during combat does not create permanently blocked cities
- [x] All existing tests pass
- [x] New tests cover: stale siege cleanup, phantom stack filtering, stale selection
