# Visible Unit Types

## Description
Make the unit type composition more visible on stacks so players can quickly identify what units a stack contains without needing to select it.

## Systems Affected
- scripts/presentation/unit_renderer.gd
- scenes/map/city_node.tscn / city_node.gd (if stack icons shown on cities)

## Implementation Notes
- Show unit type icons (Infantry/Cavalry/Artillery) on or near the stack indicator
- Consider small icons or colored pips per unit type
- Counts per type should be readable at a glance
- Should work for both player and enemy stacks (when visible)

## Acceptance Criteria
- [ ] Unit types within a stack are visually distinguishable without selecting
- [ ] Player can tell at a glance which unit types are in a stack
- [ ] Works for both friendly and visible enemy stacks
