# Ashes of the Vistula — Territorial Command

## Project Overview

A fast-paced, low-APM territorial strategy game set in Poland during 1650–1670. Players wage war by moving armies between cities, besieging fortifications, and shaping territorial geometry. Simple military conquest mechanics create emergent economic dominance.

### Design Pillars

1. **Simple conquest mechanics** — Select stack → move to adjacent city → siege → battle
2. **Territory defines power** — Controlling 3+ cities encloses land, increasing global supply
3. **Command is scarce** — Limited order pool constrains decision bandwidth
4. **Fast, readable combat** — Two-phase siege model with deterministic resolution
5. **Low mechanical skill requirement** — Planning and timing over APM

### Target Match Length

15–20 minutes (1v1)

## Tech Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Engine** | Godot 4 (2D) | Game engine, rendering, input |
| **Language** | GDScript | All gameplay code |
| **Data Format** | JSON | Balance values, maps, scenarios |
| **Version Control** | Git | Source control |
| **Target Platform** | macOS | Primary dev and playtest target |

C# is intentionally avoided to reduce setup complexity and iteration friction.

## Repository Structure

```
Ashes-of-the-Vistula/
├── CLAUDE.md                        # This file — AI agent instructions
├── PRD.md                           # Product requirements document
├── tech_approach.md                 # Engine and architecture decisions
├── project.godot                    # Godot project file
├── data/
│   ├── balance.json                 # All tunable gameplay values
│   ├── map.json                     # City positions, adjacency, terrain
│   └── scenario.json                # Starting ownership, units, win conditions
├── scenes/
│   ├── main.tscn                    # Root scene
│   ├── game/
│   │   ├── game.tscn                # Main game scene
│   │   └── game.gd
│   ├── map/
│   │   ├── hex_map.tscn             # Hex grid + city nodes
│   │   ├── hex_map.gd
│   │   ├── city_node.tscn           # Individual city visual
│   │   └── city_node.gd
│   ├── ui/
│   │   ├── hud.tscn                 # In-game HUD (supply, orders, timer)
│   │   ├── hud.gd
│   │   ├── admin_panel.tscn         # Debug/balance tuning panel
│   │   ├── admin_panel.gd
│   │   ├── stack_info.tscn          # Selected stack details
│   │   └── stack_info.gd
│   └── combat/
│       ├── siege_display.tscn       # Siege progress visualization
│       └── battle_display.tscn      # Battle resolution visualization
├── scripts/
│   ├── simulation/                  # Pure game state — NO rendering code
│   │   ├── game_state.gd            # Top-level simulation state
│   │   ├── city.gd                  # City data: tier, HP, production, ownership
│   │   ├── unit_stack.gd            # Stack composition and movement
│   │   ├── combat_resolver.gd       # Siege + battle resolution
│   │   ├── supply_system.gd         # Global supply cap calculation
│   │   ├── command_system.gd        # Order pool and regeneration
│   │   ├── territory_system.gd      # Triangle detection, enclosed hex calc
│   │   ├── dominance_system.gd      # Win condition timer
│   │   └── config_loader.gd         # JSON config loading and hot-reload
│   ├── presentation/                # Reads from simulation, renders to screen
│   │   ├── map_renderer.gd          # Hex grid drawing and territory overlay
│   │   ├── unit_renderer.gd         # Stack icons and movement animation
│   │   ├── combat_renderer.gd       # Siege/battle progress bars and effects
│   │   └── fog_renderer.gd          # Fog of war overlay
│   ├── ai/
│   │   └── ai_controller.gd         # AI opponent logic
│   └── autoload/
│       └── game_config.gd           # Autoloaded singleton for balance data
├── assets/
│   ├── tiles/                       # Hex tile sprites
│   ├── icons/                       # City and unit icons
│   ├── ui/                          # UI theme and elements
│   └── audio/                       # Sound effects (future)
├── docs/
│   └── tickets/                     # Kanban-style ticket board
│       ├── TODO/                    # Tickets ready to be picked up
│       ├── DOING/                   # Tickets currently in progress
│       └── DONE/                    # Completed tickets
└── tests/
    ├── unit/                        # Fast, isolated simulation tests
    │   ├── test_combat_resolver.gd  # Combat math and phase transitions
    │   ├── test_supply_system.gd    # Supply cap calculations
    │   ├── test_territory_system.gd # Triangle detection, hex enclosure
    │   ├── test_command_system.gd   # Order pool, regen, spending
    │   ├── test_dominance_system.gd # Win condition trigger and timer
    │   ├── test_city.gd             # City production, tiers, caps
    │   └── test_unit_stack.gd       # Stack splitting, merging, movement
    ├── integration/                 # Full simulation loop tests (slower)
    │   ├── test_game_loop.gd        # Multi-tick game scenarios
    │   ├── test_ai_behavior.gd      # AI decision-making validation
    │   └── test_config_loading.gd   # JSON load, hot-reload, bad data
    └── test_runner.gd               # Headless test runner entry point
```

## Architecture

The codebase is split into two strictly separated layers.

### Simulation Layer (`scripts/simulation/`)

Pure game state. This layer:
- Owns all authoritative data (cities, stacks, supply, orders, territory, dominance)
- Runs deterministic logic (same inputs → same outputs)
- Contains **zero** rendering, UI, or Godot node tree code
- Is independently testable
- Advances via a fixed tick rate (~10 ticks/second)

### Presentation Layer (`scripts/presentation/` + `scenes/`)

Visual output. This layer:
- Reads from simulation state
- Renders the hex map, units, combat, fog
- Reacts to simulation changes via signals
- Handles player input and translates it into simulation commands
- Never mutates simulation state directly

### Data Flow

```
Player Input → Command Queue → Simulation Tick → State Change → Signal → Presentation Update
```

AI uses the same command interface as the player.

## Game Systems Reference

### Units (3 types only)

| Unit | Field DPS | Siege Damage | Speed | Role |
|------|-----------|--------------|-------|------|
| **Infantry** | Moderate | Moderate | Standard | Balanced core |
| **Cavalry** | High | Weak | Fast | Open-field power |
| **Artillery** | Low | High | Slow | Wall breaker |

All units consume 1 global supply. Units always exist in stacks. No individual unit micro.

### City Tiers

| Tier | Local Cap | Structure HP | Special |
|------|-----------|--------------|---------|
| **Hamlet** | Low | Low | — |
| **Village** | Medium | Medium | — |
| **Major City** | High | High | +Order cap, +Order regen |

### Combat (Two Phases)

1. **Siege** — Attackers damage structure HP only. Defenders untouchable. Structure regenerates if attackers retreat.
2. **Battle** — Triggers at structure HP 0. Deterministic DPS exchange. Priority targeting: Artillery → Cavalry → Infantry. City flips on defender elimination.

### Territory

3+ owned cities forming a triangle → all hexes inside become controlled territory → increased global supply + automatic vision. Territory collapses if a corner city is lost.

### Command

Players have an Order Cap (OC) and Order Regeneration Rate (ORR). Orders are spent to: move stack, split stack, initiate siege, capture neutral city. Major cities increase both OC and ORR.

### Win Condition

Dominance timer: control X% of cities AND Y% of territory hexes → countdown starts → maintain for duration → victory. Dropping below threshold pauses or resets the timer.

## Data-Driven Configuration

**No gameplay numbers are hardcoded in scripts.** All tunable values live in JSON.

### `data/balance.json`

```json
{
  "units": {
    "infantry": { "hp": 100, "dps": 10, "siege_damage": 5, "speed": 1.0, "production_time": 5.0 },
    "cavalry":  { "hp": 80,  "dps": 15, "siege_damage": 2, "speed": 1.5, "production_time": 7.0 },
    "artillery":{ "hp": 60,  "dps": 5,  "siege_damage": 20,"speed": 0.6, "production_time": 10.0 }
  },
  "cities": {
    "hamlet":     { "local_cap": 5,  "structure_hp": 100, "production_interval": 8.0 },
    "village":    { "local_cap": 10, "structure_hp": 200, "production_interval": 6.0 },
    "major_city": { "local_cap": 20, "structure_hp": 400, "production_interval": 4.0 }
  },
  "supply": {
    "base_cap": 20,
    "per_territory_hex": 0.5,
    "per_major_city": 5,
    "per_minor_city": 2
  },
  "command": {
    "base_order_cap": 3,
    "base_regen_rate": 0.1,
    "major_city_cap_bonus": 1,
    "major_city_regen_bonus": 0.05
  },
  "dominance": {
    "city_threshold_pct": 60,
    "territory_threshold_pct": 50,
    "timer_duration": 120.0
  }
}
```

### `data/map.json`

City positions (hex coordinates), city tiers, production types, adjacency connections, and terrain layout.

### `data/scenario.json`

Starting city ownership, initial unit placements, and per-scenario victory condition overrides.

### Hot-Reload

The admin panel can reload all JSON configs at runtime without restarting the game. `config_loader.gd` watches for reload signals and propagates new values to all systems.

## Code Conventions

### GDScript Style

- Follow the [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- `snake_case` for variables, functions, signals, and file names
- `PascalCase` for class names and node names
- `UPPER_SNAKE_CASE` for constants and enums
- Type hints on all function signatures and member variables
- Use `@export` for inspector-tunable values only when JSON config is impractical
- Use signals for simulation → presentation communication
- Never use `get_node()` with long paths; store `@onready` references

### File Organization

- One script per logical concern
- Simulation scripts must never `extends Node` if they don't need the scene tree (use `RefCounted` or `Resource`)
- Scene scripts (`.tscn` + `.gd`) live together in the same directory
- Autoloaded singletons go in `scripts/autoload/`

### Simulation Rules (Strict)

- `scripts/simulation/` must **never** reference `scripts/presentation/`, `scenes/`, or any Godot rendering API
- All randomness (if any) must be seeded and reproducible
- State changes happen only during simulation ticks, never during input or rendering
- All combat math is deterministic — no `randf()` in resolution

### Signal Naming

```
signal city_captured(city_id: int, new_owner: int)
signal siege_started(city_id: int, attacker_stack_id: int)
signal stack_moved(stack_id: int, from_city: int, to_city: int)
signal territory_changed(player_id: int, hex_list: Array)
signal dominance_triggered(player_id: int)
signal dominance_ended(player_id: int)
```

### Commit Messages

```
feat: add territory polygon detection
fix: correct supply calculation when city lost
balance: adjust artillery siege damage values
ui: add order counter to HUD
ai: improve siege target selection
data: update map adjacency for Poland prototype
test: add combat resolver edge case tests
refactor: extract supply logic from game_state
```

## Admin & Balance Panel

The in-game admin panel (`scenes/ui/admin_panel.tscn`) is a critical development tool:

- **View** all current balance values from loaded JSON
- **Edit** values at runtime via sliders and input fields
- **Reload** JSON configs without restarting the match
- **View** derived state: current supply caps, order pools, territory sizes, dominance progress
- **Reset** the match instantly for rapid playtesting
- **Toggle** with a keyboard shortcut (e.g., F12)

All parameters from `data/balance.json` must be editable through this panel.

## AI Design

The AI opponent:
- Uses the exact same rules and command interface as the player
- Evaluates siege viability (can I break this city before reinforcements?)
- Assesses reinforcement timing
- Values territory geometry (prioritizes triangle-forming cities)
- Competes without cheating mechanics (no extra vision, no free orders)
- Difficulty can be tuned by adjusting AI decision frequency and evaluation weights

## Development Method

### Test-Driven Development (Strict TDD)

**All simulation code must follow the Red-Green-Refactor cycle. No exceptions.**

1. **Red** — Write a failing test first
2. **Green** — Write the minimal code to make the test pass
3. **Refactor** — Clean up while keeping tests green

**TDD Rules:**
- Never write simulation code without a failing test
- Write only enough test code to fail (parse errors count as failure)
- Write only enough production code to pass the failing test
- Tests are first-class citizens — maintain them like production code
- If you find a bug, write a test that reproduces it before fixing it

**What must be tested (mandatory):**
- All simulation logic (`scripts/simulation/`)
- All combat math (siege damage, DPS exchange, targeting priority)
- Supply cap calculations (base + territory + cities)
- Territory polygon detection (triangle formation, hex enclosure, collapse)
- Command system (order spending, regeneration, cap increases)
- Dominance system (trigger conditions, timer behavior, reset on loss)
- Config loading (valid data, missing fields, corrupt JSON)
- AI decision logic

**What does not require tests:**
- Scene tree wiring (`.tscn` files)
- Pure presentation code (renderers, animations, UI layout)
- Godot editor configuration

**Test Structure:**
```
tests/
├── unit/                        # Fast, isolated — test one system at a time
│   ├── test_combat_resolver.gd
│   ├── test_supply_system.gd
│   ├── test_territory_system.gd
│   ├── test_command_system.gd
│   ├── test_dominance_system.gd
│   ├── test_city.gd
│   └── test_unit_stack.gd
├── integration/                 # Full game loop — multi-system interaction
│   ├── test_game_loop.gd
│   ├── test_ai_behavior.gd
│   └── test_config_loading.gd
└── test_runner.gd               # Headless entry point
```

**Testing Commands:**
```bash
# Run all tests (headless)
godot --path . --headless -s tests/test_runner.gd

# Run only unit tests (fast feedback loop during TDD)
godot --path . --headless -s tests/test_runner.gd -- --unit

# Run only integration tests
godot --path . --headless -s tests/test_runner.gd -- --integration

# Run a specific test file
godot --path . --headless -s tests/test_runner.gd -- --file=test_combat_resolver.gd
```

**Test Naming Convention:**
```gdscript
# Test function names describe the behavior being verified
func test_infantry_deals_moderate_siege_damage() -> void:
func test_artillery_targets_first_in_battle_priority() -> void:
func test_territory_collapses_when_corner_city_lost() -> void:
func test_dominance_timer_resets_below_threshold() -> void:
func test_supply_cap_increases_with_enclosed_territory() -> void:
func test_order_pool_cannot_exceed_cap() -> void:
```

### Ticket Workflow

Work items are tracked as Markdown files in a Kanban-style directory structure:

```
docs/tickets/
├── TODO/          # Tickets ready to be picked up
├── DOING/         # Tickets currently in progress (max 1 at a time)
└── DONE/          # Completed tickets
```

### Ticket Lifecycle

1. **TODO** — New tickets are created as `.md` files in `docs/tickets/TODO/`
2. **DOING** — When work begins, move the file to `docs/tickets/DOING/`
3. **DONE** — When all acceptance criteria are met, move to `docs/tickets/DONE/`

### Ticket Completion Checklist

Every ticket must go through this full pipeline before moving to DONE:

1. **Move ticket to DOING** — `mv docs/tickets/TODO/<ticket>.md docs/tickets/DOING/`
2. **Create feature branch and push** — `git checkout -b feature/<ticket-slug> && git push -u origin feature/<ticket-slug>`
3. **Write failing tests** (TDD Red) — unit tests for the new behavior
4. **Implement the feature** (TDD Green) — minimal code to pass the tests
5. **Refactor** — clean up while all tests stay green
6. **Commit and push** — small, focused commits throughout; push to remote regularly
7. **Run full test suite** — `godot --path . --headless -s tests/test_runner.gd` (all must pass)
8. **Playtest manually** — launch the game and verify the feature works in context
9. **Check off acceptance criteria** in the ticket `.md` file
10. **Move ticket to DONE** — `mv docs/tickets/DOING/<ticket>.md docs/tickets/DONE/`
11. **Final commit and push** — commit the ticket move and any last changes, push the branch
12. **Merge to main and push** — `git checkout main && git pull origin main && git merge --no-ff feature/<ticket-slug> && git push origin main`
13. **Clean up branch** — `git branch -d feature/<ticket-slug> && git push origin --delete feature/<ticket-slug>`

### Ticket File Format

Each ticket is a Markdown file named with a short kebab-case slug (e.g., `siege-phase-combat.md`):

```markdown
# Siege Phase Combat Resolution

## Description
Implement the siege phase where attackers damage structure HP.
Defenders cannot be damaged during siege. Structure regenerates
if attackers retreat.

## Systems Affected
- combat_resolver.gd
- city.gd (structure HP)

## Implementation Notes
- Siege damage is sum of all units' siege_damage stat in the attacking stack
- Damage applied per simulation tick
- Structure HP regeneration rate comes from balance.json
- Siege ends when structure HP reaches 0 (triggers battle phase)

## Acceptance Criteria
- [ ] Attacking stack reduces city structure HP by total siege damage per tick
- [ ] Defenders take zero damage during siege phase
- [ ] Structure HP regenerates when no attackers present
- [ ] Structure HP stops regenerating while under active siege
- [ ] Siege → battle transition triggers at structure HP 0
- [ ] All behavior driven by balance.json values
- [ ] Unit tests cover all criteria above
- [ ] Integration test: full siege → battle → city capture sequence
```

### Ticket Rules

- One ticket per file
- Keep ticket names descriptive but concise
- Always **move** (not copy) tickets between columns
- A ticket in DOING should have a corresponding feature branch
- A ticket moves to DONE only when **all** acceptance criteria are checked off
- Maximum one ticket in DOING at a time — finish before starting next
- Tickets should be small enough to complete in a single focused session

### Git Workflow & Branching Strategy

**Repository:** A single remote (`origin`) on GitHub. All work is pushed to remote. No PRs required — merges happen locally, but every branch and every merge is pushed so the remote always reflects the full project history.

**Branch Types:**

| Branch | Purpose | Branches From | Merges To |
|--------|---------|---------------|-----------|
| `main` | Stable, playable builds — always works | — | — |
| `feature/<slug>` | New game systems and features | `main` | `main` |
| `bugfix/<slug>` | Bug fixes | `main` | `main` |
| `balance/<slug>` | Tuning and data-only changes | `main` | `main` |

**Branch Naming — use the ticket slug:**
```
feature/siege-phase-combat
feature/territory-polygon-detection
feature/admin-balance-panel
bugfix/supply-cap-off-by-one
balance/artillery-siege-damage-tuning
```

### Branch Lifecycle (Step by Step)

```bash
# 1. Start from a clean, up-to-date main
git checkout main
git pull origin main

# 2. Create the feature branch
git checkout -b feature/<ticket-slug>

# 3. Push the branch to remote immediately (establishes tracking)
git push -u origin feature/<ticket-slug>

# 4. Work: TDD loop — write tests, implement, refactor
#    Commit frequently in small, focused increments
git add -A
git commit -m "test: add failing tests for siege damage calculation"

git add -A
git commit -m "feat: implement siege damage per tick"

git add -A
git commit -m "refactor: extract siege logic into dedicated method"

# 5. Push work-in-progress to remote regularly (at minimum after every session)
git push

# 6. When the ticket is complete and all tests pass:
#    Switch to main, pull latest, merge with --no-ff, push
git checkout main
git pull origin main
git merge --no-ff feature/<ticket-slug>
git push origin main

# 7. Delete the feature branch (local and remote)
git branch -d feature/<ticket-slug>
git push origin --delete feature/<ticket-slug>
```

### Commit Discipline

**Commit early, commit often.** Each commit should be a single logical change.

**Commit message format:** `<type>: <description>`

```
feat: add territory polygon detection
feat: implement order pool regeneration
fix: correct supply calculation when city lost
test: add combat resolver edge case tests
refactor: extract supply logic from game_state
balance: adjust artillery siege damage values
data: update map adjacency for Poland prototype
ui: add order counter to HUD
ai: improve siege target selection
docs: add siege-phase-combat ticket
```

**Rules:**
- Every commit message starts with a type prefix
- Description is lowercase, imperative mood, no period
- One logical change per commit — don't bundle unrelated work
- Tests and implementation can be in the same commit when they're for the same behavior
- Never commit broken code to `main` — broken code on feature branches is acceptable mid-session

### Push Discipline

**Push to remote after:**
- Creating a new branch (immediately, with `-u` to set tracking)
- Completing a TDD cycle (test + implementation passing)
- Ending a work session (even if mid-ticket — push WIP to the feature branch)
- Merging to `main` (push main immediately after merge)
- Deleting a finished feature branch (clean up remote too)

**Never push:**
- Directly to `main` without merging a branch first
- Code that doesn't compile or parse

### Main Branch Rules

`main` is the stable trunk. It must always be in a playable state.

- **Never commit directly to `main`** — all changes arrive via `--no-ff` merges from feature/bugfix/balance branches
- **Always pull before merge** — `git pull origin main` before merging to avoid conflicts
- **Push immediately after merge** — `git push origin main` so the remote stays current
- **Every merge to `main` should pass the full test suite** — run tests before the merge, not after

### Version Control Rules

- `.godot/` import cache is gitignored; `project.godot` is tracked
- `data/*.json` balance/map/scenario files are tracked — these are first-class source files
- All balance changes happen in `data/` JSON files, not in script edits
- No large binary assets in git — use `.gitignore` for generated builds and temporary files
- AI-assisted code generation is fine; review and test before committing

### Development Rhythm

The standard working session follows this loop:

1. **Pick a ticket** from `docs/tickets/TODO/` → move to `DOING/`
2. **Branch and push** — `git checkout -b feature/<slug>` → push to remote with `-u`
3. **TDD loop** — Red → Green → Refactor → commit → push (repeat until acceptance criteria met)
4. **Test** — Run full suite headless
5. **Play** — Launch the game, verify the feature works, check for regressions
6. **Ship** — Check off criteria, move ticket to `DONE/`, commit, push branch
7. **Merge** — Pull main, merge `--no-ff`, push main, delete branch (local + remote)
8. **Repeat**

Balance tuning sessions are different:
1. Launch the game with the admin panel open (F12)
2. Adjust values in real-time via the panel
3. When satisfied, export the values to `data/balance.json`
4. Create `balance/<slug>` branch, commit, push
5. Merge to `main`, push, delete branch

**End-of-session rule:** If you stop mid-ticket, always push your feature branch to remote before ending. Never leave work only on your local machine.

## Commands

```bash
# === Editor & Running ===
godot --path . --editor                                  # Open in Godot editor
godot --path . --main-scene scenes/main.tscn             # Run the game

# === Testing ===
godot --path . --headless -s tests/test_runner.gd                            # All tests
godot --path . --headless -s tests/test_runner.gd -- --unit                  # Unit tests only (fast)
godot --path . --headless -s tests/test_runner.gd -- --integration           # Integration tests only
godot --path . --headless -s tests/test_runner.gd -- --file=test_combat_resolver.gd  # Single file

# === Ticket Workflow ===
mv docs/tickets/TODO/<ticket>.md docs/tickets/DOING/     # Start work on ticket
mv docs/tickets/DOING/<ticket>.md docs/tickets/DONE/     # Complete ticket

# === Git Workflow ===
git checkout main && git pull origin main                # Start from clean main
git checkout -b feature/<slug>                           # Create feature branch
git push -u origin feature/<slug>                        # Push branch to remote (first time)
git push                                                 # Push commits (subsequent)
git checkout main && git pull origin main                # Prepare to merge
git merge --no-ff feature/<slug>                         # Merge completed work
git push origin main                                     # Push merged main to remote
git branch -d feature/<slug>                             # Delete local branch
git push origin --delete feature/<slug>                  # Delete remote branch

# === Export ===
godot --path . --export-release "macOS" builds/ashes-of-the-vistula.dmg
```

## Important Notes

### Determinism is Non-Negotiable

The simulation layer must produce identical results given identical inputs. This is the foundation for:
- Reliable AI behavior
- Future multiplayer (lockstep or replay-based)
- Automated testing
- Replay systems

If you need randomness, use a seeded `RandomNumberGenerator` stored in `game_state.gd`.

### No Hardcoded Gameplay Numbers

Every gameplay value (HP, DPS, timers, thresholds, caps) must come from `data/balance.json`. If you find yourself writing a magic number in simulation code, move it to config.

### Simulation Purity

`scripts/simulation/` is the most protected directory. Before modifying any file there:
1. Verify it contains no rendering or UI code
2. Ensure all state changes are deterministic
3. Confirm the change doesn't break the simulation/presentation boundary

### MVP Scope

The initial build targets:
- Single historical map (Poland region, 12–20 cities)
- 3 unit types (Infantry, Cavalry, Artillery)
- Supply + command systems
- Siege + battle model
- Territory polygon system
- Dominance win condition
- Basic AI opponent
- Admin/balance panel

### Non-Goals (for MVP)

- No weather system
- No attrition mechanics
- No morale system
- No super-weapons
- No complex resource economy
- No diplomacy
- No multiplayer networking (architecture supports it later)

### Performance

The game is small-scale and systems-heavy, not graphically intensive:
- 12–20 cities, small number of stacks
- ~10 simulation ticks/second
- Minimal physics usage
- Godot 4's 2D renderer is more than sufficient

### Future Expansion Path

The deterministic, data-driven architecture supports:
- Additional factions with asymmetric bonuses
- Multiplayer (1v1, 3–4 players)
- Larger maps
- Expanded AI with difficulty levels
- Deeper UI and visual polish

---

*Refer to `PRD.md` for full game design details and `tech_approach.md` for engine rationale.*
