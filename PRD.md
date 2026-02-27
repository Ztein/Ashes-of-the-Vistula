Product Requirements Document, Poland 1650 – Territorial Command

1. Working title

Poland 1650 – Territorial Command

⸻

2. Vision

A fast-paced, low-APM territorial strategy game set in Poland during 1650–1670. Players wage war by moving armies between cities, besieging fortifications, and shaping territorial geometry. Simple military conquest mechanics create emergent economic dominance.

The game emphasizes:
	•	Clear systems
	•	Fast tempo
	•	Strategic commitment
	•	Territorial shaping
	•	Limited but meaningful decision bandwidth

⸻

3. Core pillars
	1.	Simple conquest mechanics
	•	Select stack → order move to adjacent city → siege → battle.
	2.	Territory defines power
	•	Controlling 3+ cities creates enclosed land.
	•	Enclosed land increases global supply.
	3.	Command is scarce
	•	Players operate through a limited order pool.
	•	Major cities increase command ability.
	4.	Fast, readable combat
	•	Two-phase siege model.
	•	Deterministic unit combat.
	5.	Low mechanical skill requirement
	•	No high APM advantage.
	•	Focus on planning and timing.

⸻

4. Target match length

15–20 minutes

⸻

5. Game loop
	1.	Produce units in cities
	2.	Issue limited orders
	3.	Move stacks between cities
	4.	Break city walls (siege phase)
	5.	Resolve combat (battle phase)
	6.	Capture cities
	7.	Form territorial polygons
	8.	Increase supply and command capacity
	9.	Trigger dominance timer

⸻

6. Map structure
	•	Hex-based map
	•	Pre-placed cities (hamlets, villages, major cities)
	•	Terrain types (roads, forests, rivers, plains)
	•	Movement is city-to-city only

Cities function as nodes in a network.

⸻

7. Units

Three unit types only.

Infantry
	•	Balanced core unit
	•	Moderate DPS
	•	Moderate siege damage
	•	Standard production rate

Cavalry
	•	High field DPS
	•	Weak siege damage
	•	Fast movement
	•	Strong in open-field battles

Artillery
	•	Low combat DPS
	•	High siege damage
	•	Slow production
	•	Essential for breaking fortified cities

All units consume 1 global supply.

Units always exist as stacks.
Stacks can be split.
No individual unit micro.

⸻

8. City system

Cities have:
	•	Production type (fixed per city)
	•	Local unit cap
	•	Structure HP
	•	Production interval

City tiers

Hamlet
	•	Low local cap
	•	Low structure HP

Village
	•	Medium local cap
	•	Medium structure HP

Major City
	•	High local cap
	•	High structure HP
	•	Increases command ability

Cities stop producing when:
	•	Local cap reached
	•	Global supply cap reached

⸻

9. Combat model

Phase 1: Siege
	•	Attackers damage Structure HP only
	•	Defenders cannot be damaged
	•	Structure does not regenerate while under attack
	•	If attackers retreat, structure regenerates

Phase 2: Battle
	•	Triggered when Structure HP reaches 0
	•	Deterministic DPS exchange
	•	Simultaneous damage
	•	Priority targeting (Artillery → Cavalry → Infantry)

If defenders eliminated:
	•	City flips ownership
	•	Structure HP resets

⸻

10. Supply system

Global Supply Cap (GSL)
	•	Base supply limit
	•	Each unit consumes 1 supply
	•	Production halts when limit reached

Supply increases via:
	•	Enclosed territory (polygon land)
	•	Major cities
	•	Minor cities

Local city cap
	•	Each city has maximum stack capacity
	•	Cannot exceed local cap
	•	Production halts when local cap reached

⸻

11. Territory system

If a player controls 3+ cities forming a triangle:
	•	All hexes inside become controlled territory

Territory provides:
	•	Increased global supply
	•	Automatic vision within territory

Territory collapses if a corner city is lost.

⸻

12. Command system

Players have:
	•	Order Cap (OC)
	•	Order Regeneration Rate (ORR)

Base values:
	•	Limited order pool
	•	Regenerates over time
	•	Cannot exceed cap

Orders are required to:
	•	Move stack
	•	Split stack
	•	Initiate siege
	•	Capture neutral city

Major cities increase:
	•	Order cap
	•	Order regeneration rate

⸻

13. Win condition

Dominance Timer model:

A player triggers dominance if:
	•	Controls X% of cities
	•	Controls Y% of total territory hexes

When triggered:
	•	Countdown begins
	•	If conditions maintained for duration → victory
	•	If conditions drop below threshold → timer pauses or resets

⸻

14. Multiplayer
	•	1v1 primary mode
	•	Future support for 3–4 players
	•	Potential faction asymmetry (future iteration)

⸻

15. AI design goals

AI must:
	•	Evaluate siege viability
	•	Assess reinforcement timing
	•	Value territory geometry
	•	Compete without cheating mechanics

AI uses same rules as player.

⸻

16. Admin & tuning interface (critical requirement)

Game must include adjustable configuration panel for rapid balancing:

Adjustable parameters include:
	•	Structure HP per city tier
	•	Production interval per city tier
	•	Unit HP and DPS
	•	Siege damage values
	•	Global supply base value
	•	Supply per territory hex
	•	Order cap
	•	Order regeneration rate
	•	Dominance thresholds
	•	Dominance timer duration

All parameters editable without code changes.

⸻

17. Non-goals (for MVP)
	•	No weather system
	•	No attrition mechanics
	•	No morale system
	•	No super-weapons
	•	No complex resource economy
	•	No diplomacy (initial version)

⸻

18. MVP scope
	•	Single historical map (Poland region prototype)
	•	12–20 cities
	•	3 unit types
	•	Supply + command systems
	•	Siege + battle model
	•	Dominance win condition
	•	Basic AI opponent

⸻

19. Design summary

This game combines:
	•	Fast siege warfare
	•	Deterministic combat
	•	Geometric territorial dominance
	•	Limited command bandwidth

The player wins not by clicking faster, but by:
	•	Shaping territory
	•	Managing supply
	•	Timing sieges
	•	Breaking opponent geometry

The system is intentionally minimal, tunable, and strategically deep.