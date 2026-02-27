# MVP Polish and Integration

## Description
Final integration pass. Main menu, victory/defeat screens, clean game restart, performance verification, full test suite pass.

## Systems Affected
- scenes/main.tscn
- scenes/game/game.gd
- Various UI scenes

## Implementation Notes
- Minimal main menu: "Start Game" button
- Victory screen on dominance timer expiry
- Defeat screen when AI wins
- Clean restart from admin panel and main menu
- Verify full match plays in ~15-20 minutes
- Run complete test suite
- Remove TODO comments and temporary code

## Acceptance Criteria
- [x] Game launches from main menu
- [x] Full match against AI with all systems
- [x] Victory screen on player win
- [x] Defeat screen on AI win
- [x] Restartable without app restart
- [x] All tests pass
- [x] No hardcoded gameplay values
- [x] ~15-20 minute match length
- [x] Smooth performance
