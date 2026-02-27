# Combat Not Triggering When Both Players Have Units at Same City

## Description
When both player and enemy stacks are present at the same city, combat (siege/battle) does not appear to take place. Units from opposing players coexist at a city without fighting.

The current design requires an explicit `START_SIEGE` command to initiate combat. However, when an attacking stack arrives at an enemy-held city, it seems like neither the player nor the AI reliably initiates siege, resulting in stacks sitting idle at the same location.

## Observed Behavior
- Player and enemy stacks occupy the same city (visible in screenshot: Radom has both blue player stack and red enemy stack)
- No siege or battle is triggered automatically
- Units just coexist without engaging

## Expected Behavior
- When opposing stacks are at the same city, combat should engage (either automatically or the AI should reliably issue START_SIEGE commands)
- At minimum, the AI should always siege enemy cities where it has stacks present

## Investigation Areas
- `game_state.gd` — Does the tick loop check for colocated enemy stacks and trigger combat?
- `combat_resolver.gd` — Is siege/battle being resolved correctly when stacks are present?
- `ai_controller.gd` — Is the AI issuing START_SIEGE commands when its stacks arrive at enemy cities?
- Consider whether siege should auto-trigger when an attacking stack arrives at an enemy city (removing the need for a separate START_SIEGE command)

## Systems Affected
- game_state.gd (tick loop, command processing)
- combat_resolver.gd (siege/battle triggering)
- ai_controller.gd (siege command issuance)

## Root Cause
The tick loop only processed sieges for cities in the `_sieges` dictionary, which was only populated by explicit `START_SIEGE` commands. Combined with the pinning rule (can't move away with enemies present), this created a deadlock.

## Fix
Added `_auto_start_sieges()` method to tick loop between movement and siege phases. It scans all cities for colocated enemy stacks and auto-starts sieges with no order cost.

## Acceptance Criteria
- [x] Diagnose root cause: determine why combat isn't happening at colocated cities
- [x] Fix the issue so that opposing stacks at the same city engage in combat
- [x] AI reliably sieges enemy cities where it has stacks
- [x] Player can initiate siege against enemy cities with their stacks
- [x] Unit tests cover the fix
- [x] Integration test: stack arrives at enemy city → siege begins → battle resolves
