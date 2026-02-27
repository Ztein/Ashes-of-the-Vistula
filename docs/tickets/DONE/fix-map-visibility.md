# Fix Map Visibility

## Description
Some cities fall outside the visible area at game start and may be hard to reach. Ensure the full map is playable and all cities are accessible without excessive scrolling.

## Problem
City pixel positions (hex_position * 64) span y=64 (Gdansk) to y=896 (Krakow, Lwow), but the viewport is 720px tall. With the camera starting at (640, 480), cities at the top and bottom edges are clipped. There are no camera bounds preventing scrolling into empty space either.

## Systems Affected
- data/map.json (city positions)
- scenes/game/game.gd (camera setup)
- scenes/map/hex_map.gd (HEX_SCALE, fog background rect)

## Possible Approaches
1. **Reposition cities** — Adjust hex_positions so all cities fit comfortably within the viewport at default zoom
2. **Auto-fit camera** — On game start, calculate the bounding box of all cities and set camera zoom/position to show the full map
3. **Camera bounds** — Clamp camera movement so it can't scroll past the map edges
4. **Combination** — Tighten city positions and add camera bounds for polish

## Acceptance Criteria
- [ ] All 15 cities are visible or easily reachable from the initial camera view
- [ ] Camera cannot scroll far into empty space beyond the map
- [ ] City labels and stack indicators are not clipped at map edges
- [ ] Map feels compact and playable without excessive panning
