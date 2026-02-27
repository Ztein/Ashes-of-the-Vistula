# Game Menu

## Description
Add an in-game menu that allows the player to quit, restart, or give up (concede) the current game.

## Systems Affected
- scenes/ui/ (new menu scene or addition to existing HUD)
- scenes/game/game.gd
- scenes/main.tscn / main.gd
- scripts/simulation/game_state.gd (concede / early victory trigger)

## Implementation Notes
- Toggle menu with Escape key
- Menu options: Resume, Restart Game, Give Up, Quit to Main Menu / Quit Game
- Pause the simulation while menu is open
- Simple overlay panel on top of the game view
- Give Up triggers an immediate victory for the opponent
- Give Up should have a confirmation prompt to prevent accidental concession

## Acceptance Criteria
- [ ] Escape key opens/closes the in-game menu
- [ ] Restart option resets the game to initial state
- [ ] Quit option exits the game or returns to main menu
- [ ] Game simulation pauses while menu is open
- [ ] Menu closes on Resume or pressing Escape again
- [ ] Give Up option triggers opponent victory after confirmation
- [ ] Game over screen shows after giving up
