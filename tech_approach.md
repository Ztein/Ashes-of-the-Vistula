Ashes of the Vistula

Engine and Technical Approach (High-Level)

⸻

1. Purpose of This Document

This document describes the high-level technical direction for building Ashes of the Vistula, including engine choice, architectural philosophy, tooling, and iteration strategy.

The goal is fast iteration, clean systems, and strong support for playtesting and balance tuning.

⸻

2. Engine Choice: Godot 4 (2D)

Why Godot

Godot 4 is selected as the primary engine for prototyping and early production because it offers:
	•	Fast iteration speed
	•	Lightweight project setup
	•	Excellent 2D support
	•	Simple scripting model
	•	Easy macOS export
	•	Minimal external dependencies

The game is systems-heavy and UI-driven rather than graphically complex. Godot’s architecture aligns well with deterministic simulations and data-driven tuning.

Unity may be considered in the future for large-scale production, but Godot is ideal for early development and rapid experimentation.

⸻

3. Language Choice: GDScript

GDScript is selected for the following reasons:
	•	Python-like syntax
	•	Fast to write and refactor
	•	Tight integration with Godot
	•	Excellent for rapid prototyping

C# is intentionally avoided in early development to reduce setup complexity and iteration friction.

⸻

4. Core Technical Philosophy

The project will follow four core technical principles:
	1.	Deterministic simulation
	2.	Data-driven balance
	3.	Clear separation between simulation and presentation
	4.	Rapid tunability

⸻

5. Simulation Architecture

The game will be divided into two logical layers:

A. Simulation Layer (Pure Game State)

Responsibilities:
	•	Cities and ownership
	•	Unit stacks
	•	Production timers
	•	Siege resolution
	•	Battle resolution
	•	Global supply cap
	•	Local city caps
	•	Order pool and regeneration
	•	Territory triangle detection
	•	Dominance timer

This layer must:
	•	Contain no rendering code
	•	Be deterministic
	•	Be testable independently

B. Presentation Layer

Responsibilities:
	•	Rendering hex map
	•	Displaying cities and banners
	•	Visualizing movement
	•	Showing siege and battle progress
	•	Fog of war overlay
	•	UI panels and debug information

The presentation layer reads from simulation state and reacts via signals.

⸻

6. Data-Driven Configuration

All tunable gameplay values will be stored in JSON files.

Examples:

balance.json
	•	Unit HP
	•	Unit DPS
	•	Siege damage values
	•	Structure HP per city tier
	•	Production intervals
	•	Base supply cap
	•	Supply per territory hex
	•	Order cap
	•	Order regeneration rate
	•	Dominance thresholds

map.json
	•	City positions
	•	City types
	•	Adjacency connections
	•	Terrain layout

scenario.json
	•	Starting ownership
	•	Initial units
	•	Victory conditions

No gameplay numbers are hardcoded in scripts.

⸻

7. Admin & Balance Interface

A built-in debug/admin panel will allow:
	•	Reloading configuration files at runtime
	•	Viewing derived values (current supply, caps, orders, territory size)
	•	Adjusting key parameters during playtesting
	•	Resetting match instantly

This ensures rapid balance iteration without recompiling.

⸻

8. Rendering Strategy

The visual style will be optimized for clarity and speed of development.

Approach:
	•	Hex grid rendered using TileMap
	•	Cities represented by icon-based nodes
	•	Units represented as stack counters with small silhouettes
	•	Movement visualized via animated lines
	•	Siege and combat shown with simple progress bars and particle effects

The emphasis is readability and motion rather than detailed sprites.

⸻

9. Performance Considerations

The simulation tick rate will be modest (e.g., 10 ticks per second).

The game scale is limited:
	•	12–20 cities in MVP
	•	Small number of stacks
	•	Minimal physics usage

Godot’s performance is more than sufficient for this scope.

⸻

10. Version Control & Workflow
	•	Git for version control
	•	Small, incremental feature branches
	•	AI-assisted code generation with review
	•	Frequent playable builds

All balancing changes should occur in data files.

⸻

11. Target Platforms

Primary target:
	•	macOS (development and playtesting)

Future potential:
	•	Windows
	•	Linux

Godot supports easy multi-platform export if required.

⸻

12. Long-Term Flexibility

The chosen architecture allows future expansion:
	•	Additional factions
	•	Multiplayer support
	•	Larger maps
	•	Expanded AI logic
	•	Deeper UI systems

The deterministic core ensures scalability without rewriting foundational systems.

⸻

13. Summary

Ashes of the Vistula will be built in Godot 4 using GDScript, with a deterministic, data-driven architecture.

The technical focus is:
	•	Speed of iteration
	•	Clean simulation logic
	•	Tunable balance systems
	•	Clear separation of concerns

This approach supports rapid prototyping, meaningful playtesting, and long-term extensibility while keeping development friction low.