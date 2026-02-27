# Show When Combat Occurs

## Description
There is currently no visual feedback when siege or battle is happening at a city. Players cannot tell which cities are under active siege or where battles are taking place. Add clear visual indicators so players can see combat in progress.

## Expected Behavior
- Cities under active siege show a visible indicator (e.g. flashing border, siege icon, or animated effect)
- Battles in progress are visually distinct from sieges
- The player can glance at the map and immediately identify where combat is happening
- Siege progress (structure HP going down) should be clearly visible beyond just the HP bar number changing

## Possible Approaches
- Pulsing/flashing ring around cities under siege
- Crossed swords or explosion icon over cities in battle phase
- Color-coded overlay or border (e.g. orange for siege, red for battle)
- Animated HP bar drain during active siege
- Combat log or floating damage numbers
- Sound effects for siege/battle (future)

## Systems Affected
- hex_map.gd (city rendering, visual indicators)
- game_state.gd (expose active siege/battle state for presentation layer)
- Possibly new combat indicator nodes in city_node.tscn

## Implementation
Enhanced `_draw_combat_indicators()` in `hex_map.gd`:
- **Siege:** Orange pulsing ring (3 Hz) with attacker color tint, progress arc showing structure HP drain, "SIEGE" text label with dark background
- **Battle:** Red pulsing double ring (6 Hz) with attacker color tint, "BATTLE" text label with dark background
- Both indicators only show for visible cities (fog of war respected)

## Acceptance Criteria
- [x] Cities under active siege have a clear visual indicator
- [x] Battle phase is visually distinguishable from siege phase
- [x] Indicators appear/disappear correctly as combat starts/ends
- [x] Visual is readable at a glance without selecting the city
- [x] No simulation code changes needed (presentation layer only, reads from existing state)
