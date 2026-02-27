# City Data Model

## Description
Implement the City simulation class. Cities have tiers (hamlet/village/major_city), structure HP, production capability, ownership, and local unit caps. All values from balance.json.

## Systems Affected
- scripts/simulation/city.gd
- tests/unit/test_city.gd

## Implementation Notes
- Extends RefCounted (not Node — pure simulation)
- Properties: id, name, tier, owner_id, structure_hp, max_structure_hp, local_cap, production_type, production_timer, production_interval, hex_position
- Methods: init_from_config, take_siege_damage, regenerate_structure, is_structure_destroyed, tick_production, capture, get_order_cap_bonus, get_order_regen_bonus
- All values loaded from balance.json city tier config

## Acceptance Criteria
- [x] City initializes from config for all three tiers
- [x] Siege damage reduces structure HP, clamped to 0
- [x] Structure regeneration clamped to max
- [x] Production after interval, halted at local cap and global supply cap
- [x] Capture changes owner and resets structure HP
- [x] Major cities return correct order bonuses; others return 0
- [x] All values from config, none hardcoded
- [x] All unit tests pass (17 tests)
