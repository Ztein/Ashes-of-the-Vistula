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

## Acceptance Criteria
- [ ] Cities under active siege have a clear visual indicator
- [ ] Battle phase is visually distinguishable from siege phase
- [ ] Indicators appear/disappear correctly as combat starts/ends
- [ ] Visual is readable at a glance without selecting the city
- [ ] No simulation code changes needed (presentation layer only, reads from existing state)
