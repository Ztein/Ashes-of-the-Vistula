# Combat Info Panel — City Selection Shows Active Combat Details

## Description
Combat is currently impossible to understand during play. The only feedback is a pulsing ring (orange for siege, red for battle) and a structure HP bar. There's no way to see damage rates, unit matchups, or why a fight is going the way it is. This makes playtesting and balance tuning blind.

When a player selects a city that has an active siege or battle, a **Combat Info Panel** should appear showing all the relevant combat data in real time. This is essential for understanding what's happening and tuning balance values.

## Systems Affected
- `scenes/game/game.gd` (city selection triggers panel)
- New: `scenes/ui/combat_info.tscn` + `combat_info.gd` (the panel itself)
- `scripts/simulation/game_state.gd` (read combat state)
- `scripts/simulation/combat_resolver.gd` (read damage calculations)
- `scripts/simulation/unit_stack.gd` (read stack stats)

## What the Panel Should Show

### During Siege Phase
- **Phase label**: "SIEGE"
- **Structure HP**: current / max (with bar)
- **Attacker stacks**: list each stack with type, count, and siege damage contribution
- **Total siege DPS**: combined siege damage per tick from all attacker stacks
- **Estimated time to breach**: structure HP remaining / total siege DPS (in seconds)
- **Defender stacks**: list each defending stack with type and count (waiting behind walls)

### During Battle Phase
- **Phase label**: "BATTLE"
- **Attacker side**: total units, total DPS, total HP remaining
- **Defender side**: total units, total DPS, total HP remaining
- **Per-stack breakdown**: each stack's type, count, HP pool, DPS contribution
- **Targeting info**: which unit type is currently being focused (Art→Cav→Inf priority)

### When No Combat at Selected City
- Panel is hidden (same as StackInfo when no stack selected)

## Implementation Notes
- Panel should update every frame (or every simulation tick) to show live values
- Position: left side of screen or near the selected city, visually distinct from StackInfo (bottom-right)
- Keep it readable — this is a debug/playtesting tool first, pretty UI later
- Read all data from simulation state (game_state, combat_resolver, unit_stack) — presentation only
- The panel should coexist with StackInfo — both can be visible at the same time
- Use the existing signal architecture: `siege_started`, `battle_started`, `city_captured` to trigger show/hide
- Pull live data each tick from `game_state.get_stacks_at_city()`, `city.structure_hp`, stack stats

## Acceptance Criteria
- [x] Selecting a city under siege shows the combat info panel with siege details
- [x] Selecting a city in battle shows the combat info panel with battle details
- [x] Panel updates live each simulation tick (damage, HP, unit counts change in real time)
- [x] Attacker and defender sides are clearly labeled with player colors
- [x] Each stack's contribution is listed (type, count, damage output)
- [x] Total DPS for each side is shown
- [x] Estimated time to breach is shown during siege phase
- [x] Structure HP bar with current/max values is shown during siege
- [x] Panel hides when selecting a city with no active combat
- [x] Panel hides when combat ends (city captured or attackers retreat)
- [x] Panel coexists with StackInfo and HUD without overlapping
- [x] No simulation code is modified — panel is purely presentational
