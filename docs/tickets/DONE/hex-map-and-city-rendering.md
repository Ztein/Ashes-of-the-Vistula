# Hex Map and City Rendering

## Description
Visual hex map with cities, adjacency lines, territory overlay, camera controls, and click selection.

## Systems Affected
- scenes/map/hex_map.tscn + hex_map.gd
- scenes/map/city_node.tscn + city_node.gd
- scripts/presentation/map_renderer.gd
- scenes/main.tscn

## Implementation Notes
- Hex grid via _draw() override, positions from map.json
- Cities colored by owning player, sized by tier
- Adjacency lines between connected cities
- Territory: semi-transparent polygon fill per player
- Camera2D with pan (WASD/middle mouse) and zoom (scroll)
- City nodes emit city_clicked(city_id) signal

## Acceptance Criteria
- [ ] 15 cities visible at correct positions
- [ ] Cities colored by owning player
- [ ] Tier visually distinguishable (size)
- [ ] Adjacency lines between connected cities
- [ ] Territory overlay visible
- [ ] Camera pan and zoom
- [ ] City click emits signal
