# Fix Stack Selection and Movement UX

## Description
Players cannot issue move orders or cycle between stacks at a city. The root
cause is an input event ordering bug: `_unhandled_input` in `game.gd` deselects
on every left click BEFORE Area2D physics picking fires `_on_city_clicked`. This
means the selected stack is always cleared before the city click handler runs,
so moves and cycling never work.

Additionally, the stack selection UX needs improvement: players should be able
to click directly on a stack indicator to select it, and adjacent cities should
highlight when a stack is selected to show valid move targets.

## Root Cause Analysis

In Godot 4, the input processing order is:
1. `_input()` → `_gui_input()` → `_unhandled_input()` (input callbacks)
2. Viewport physics picking → Area2D `input_event` signal (happens later)

In `game.gd:_unhandled_input()` (line 194-196):
```gdscript
elif event.button_index == MOUSE_BUTTON_LEFT:
    _deselect_all()
```

This fires on EVERY left click, clearing `_selected_stack_id` to -1. Then when
`_on_city_clicked()` runs later via Area2D picking, it sees no selection and
cannot issue a move command. Cycling also fails because the handler sees no
previous selection to cycle from.

Selection appears to work because `_deselect_all()` fires first (clearing nothing
on the first click), then `_on_city_clicked` sets the selection afterward.

## Fix Approach

**Input ordering fix:**
Use a deferred deselect pattern — set a `_pending_deselect` flag in
`_unhandled_input`, clear it in `_on_city_clicked`, and only deselect in
`_process` if the flag is still set. This ensures city clicks suppress the
deselect.

**Stack indicator click areas:**
Create small Area2D click areas on each stack indicator (the "5I", "3C" labels)
so players can click a specific stack to select it, rather than only cycling
through stacks by clicking the city.

**Move destination highlighting:**
When a stack is selected, draw highlight rings on all adjacent cities to show
valid movement destinations. Dim or skip cities that can't be moved to (e.g.
pinned by enemy stacks, not enough orders).

## Systems Affected
- `scenes/game/game.gd` — input handling, deselect logic
- `scenes/map/hex_map.gd` — stack click areas, destination highlights, drawing

## Acceptance Criteria
- [ ] Left-click deselect only fires when clicking empty space (not on a city)
- [ ] Player can select a stack and move it to an adjacent city by clicking
- [ ] Clicking the same city cycles through stacks at that city
- [ ] Clicking a stack indicator directly selects that stack
- [ ] Adjacent cities highlight as valid destinations when a stack is selected
- [ ] Cities that cannot be moved to (pinning, no orders) show dimmed or no highlight
- [ ] Right-click still deselects
- [ ] Double-click on city still splits the selected stack
- [ ] All existing tests pass
