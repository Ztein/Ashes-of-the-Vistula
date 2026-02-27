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
- [x] F12 toggles panel
- [x] All balance values editable
- [x] Reload JSON from disk works
- [x] Apply changes pushes to simulation
- [x] Export writes current values to balance.json
- [x] Reset match reinitializes game state
- [x] Derived state shown accurately
- [x] Panel does not block gameplay when hidden
