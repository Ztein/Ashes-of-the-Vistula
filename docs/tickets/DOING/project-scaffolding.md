# Project Scaffolding

## Description
Create the Godot 4 project file, complete directory structure, .gitignore, all three JSON data files, the autoloaded config singleton, the config loader, and a working headless test runner with initial config-loading integration tests.

## Systems Affected
- project.godot
- .gitignore
- data/balance.json, map.json, scenario.json
- scripts/autoload/game_config.gd
- scripts/simulation/config_loader.gd
- tests/test_runner.gd
- tests/base_test.gd

## Acceptance Criteria
- [x] .gitignore excludes .godot/, builds, temp files
- [x] project.godot opens in Godot 4 editor without errors
- [x] All directories from CLAUDE.md repository structure exist
- [x] data/balance.json contains all balance values from spec
- [x] data/map.json contains 15 cities with adjacency
- [x] data/scenario.json contains valid 1v1 starting scenario
- [x] game_config.gd autoload loads balance data
- [x] config_loader.gd loads and validates JSON files
- [x] test_runner.gd discovers and runs tests headless
- [x] test_config_loading.gd passes all tests
- [ ] godot --path . --headless -s tests/test_runner.gd exits with code 0
- [ ] All 18 tickets created in docs/tickets/
