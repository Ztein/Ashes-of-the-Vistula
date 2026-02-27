# Admin Balance Panel

## Description
Runtime balance tuning panel. F12 toggle. All balance.json values editable. Reload/export JSON. Reset match. View derived state.

## Systems Affected
- scenes/ui/admin_panel.tscn + admin_panel.gd
- scripts/simulation/config_loader.gd (extend with write capability)

## Implementation Notes
- Toggle with F12
- Sections: Units, Cities, Supply, Command, Dominance, AI
- Buttons: Reload JSON, Apply Changes, Export to JSON, Reset Match
- Derived state: per-player supply, orders, territory, dominance timer
- All parameters from balance.json editable via sliders/inputs

## Acceptance Criteria
- [ ] F12 toggles panel
- [ ] All balance values editable
- [ ] Reload JSON from disk works
- [ ] Apply changes pushes to simulation
- [ ] Export writes current values to balance.json
- [ ] Reset match reinitializes game state
- [ ] Derived state shown accurately
- [ ] Panel does not block gameplay when hidden
