# Unit Rendering and Selection

## Description
Render unit stacks at cities, implement player selection and command input. Wire the game scene to run the simulation and connect input to the command queue.

## Systems Affected
- scripts/presentation/unit_renderer.gd
- scenes/ui/stack_info.tscn + stack_info.gd
- scenes/game/game.tscn + game.gd

## Implementation Notes
- Stacks visible at city positions with unit type counts
- Click city → select stack → stack info panel shows composition
- With stack selected, click adjacent city → MOVE_STACK or START_SIEGE command
- Split button in stack info → SPLIT_STACK command
- game.gd wires simulation ↔ presentation, tick timer, input → commands

## Acceptance Criteria
- [ ] Stacks visible at city positions with unit counts
- [ ] Stack selection via city click
- [ ] Stack info panel shows composition, DPS, siege damage, speed
- [ ] Move order via click on adjacent city
- [ ] Split interface
- [ ] Moving stacks animate along adjacency edge
- [ ] Simulation ticks at ~10/sec
- [ ] Commands flow through queue correctly
