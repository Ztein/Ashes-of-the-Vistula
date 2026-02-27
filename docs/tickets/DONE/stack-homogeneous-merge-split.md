# Homogeneous Stacks with Auto-Merge and Double-Click Split

## Description
Change the stack system so that each stack may only contain a single unit type (Infantry, Cavalry, or Artillery). When two same-type stacks from the same player arrive at the same city, they automatically merge into one stack. Double-clicking a stack halves it into two stacks. Clicking a different stack at the same city selects it.

This replaces the current mixed-composition stack model with a simpler, more readable one.

## Current Behavior
- Stacks can contain any mix of Infantry, Cavalry, and Artillery
- Split requires specifying exact unit counts per type via SPLIT_STACK command (costs 1 order)
- No auto-merge on arrival
- No double-click split interaction
- Stack selection within a city is limited

## New Behavior

### Homogeneous Stacks
- Each stack contains exactly one unit type
- Existing split/merge APIs and production logic must respect this constraint
- City production creates a new stack per unit type (or merges into an existing same-type stack)

### Auto-Merge on Arrival
- When a stack arrives at a city and another stack of the same player and same unit type is already there, they automatically merge (combine counts and HP pools)
- Stacks of different unit types coexist at the same city without merging
- No order cost for auto-merge

### Double-Click Split
- Double-clicking a selected stack halves it into two stacks (floor/ceil for odd counts)
- No order cost for splitting
- Both stacks remain at the same city
- If stack has only 1 unit, split is not possible

### Stack Selection
- Clicking a stack at a city selects it, replacing the previous selection
- Clicking the currently selected stack deselects it (no stack selected)
- Right-clicking or clicking empty space also deselects
- Multiple stacks of different types at one city are each independently selectable

## Systems Affected
- `scripts/simulation/unit_stack.gd` — Remove multi-type support, single unit type per stack
- `scripts/simulation/game_state.gd` — Auto-merge on arrival, update production logic, update split command
- `scripts/presentation/unit_renderer.gd` — Double-click handler, stack selection click
- `scenes/ui/stack_info.gd` — Update display for single-type stacks
- `data/scenario.json` — Update initial unit placements if needed (separate stacks per type)

## Implementation Notes
- `unit_stack.gd` should have a `unit_type` field (e.g., "infantry", "cavalry", "artillery") and a single `count` + `hp_pool`
- Remove `infantry_count`, `cavalry_count`, `artillery_count` and their separate HP pools
- Auto-merge logic runs after movement resolution in the tick loop (where arrival happens)
- Double-click split is a presentation-layer input that issues a simplified SPLIT_STACK command
- SPLIT_STACK command no longer needs per-type counts — just halves the stack
- Remove order cost from SPLIT_STACK
- Movement speed is now just the unit type's speed (no min-across-types needed)
- Combat targeting priority still applies across stacks at the same city: Art → Cav → Inf

## Acceptance Criteria
- [ ] Each stack contains exactly one unit type
- [ ] `unit_stack.gd` uses `unit_type`, `count`, and `hp_pool` instead of per-type fields
- [ ] Two same-owner, same-type stacks auto-merge when colocated at a city (after movement)
- [ ] Auto-merge combines counts and HP pools correctly
- [ ] Auto-merge has no order cost
- [ ] Double-click on a stack halves it into two stacks (no order cost)
- [ ] Split with 1 unit does nothing
- [ ] Odd-count split produces floor/ceil stacks (e.g., 5 → 2 + 3)
- [ ] Clicking a different stack at the same city selects it
- [ ] Clicking the currently selected stack deselects it
- [ ] Right-clicking or clicking empty space deselects the current stack
- [ ] City production creates/merges into same-type stacks
- [ ] Scenario starting units create separate stacks per unit type
- [ ] Combat priority targeting works across multiple stacks at a city
- [ ] All existing tests updated to reflect new single-type stack model
- [ ] New unit tests for auto-merge, halving split, and homogeneous constraint
- [ ] Integration test: move two same-type stacks to same city → auto-merge
- [ ] Integration test: double-click split → two stacks created
