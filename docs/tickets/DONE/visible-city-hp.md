# Visible City HP

## Description
Make the structure HP value of cities more visible so players can assess city fortification strength at a glance.

## Systems Affected
- scripts/presentation/map_renderer.gd or city_node.gd
- scenes/map/city_node.tscn

## Implementation Notes
- Show HP bar or HP number near the city node
- Consider a small health bar under/above the city icon
- Color-code by HP percentage (green → yellow → red)
- Should update in real-time during sieges

## Acceptance Criteria
- [ ] City structure HP is visible on the map without selecting the city
- [ ] HP display updates in real-time during siege
- [ ] Easy to assess relative fortification strength at a glance
