# Territory Polygon System

## Description
Triangle detection from 3+ mutually-adjacent same-owner cities. Hex enclosure calculation via point-in-triangle. Territory collapses when a corner city is lost.

## Systems Affected
- scripts/simulation/territory_system.gd
- tests/unit/test_territory_system.gd

## Implementation Notes
- Find all triangles: for each combo of 3 same-owner cities, check mutual adjacency
- Enclosed hexes via point-in-triangle (barycentric coordinates)
- Union of all triangles for a player = total territory
- Recalculate on city ownership change
- With 15 cities and ~200 hexes, brute force is fine

## Acceptance Criteria
- [ ] Triangles require 3 mutually adjacent, same-owner cities
- [ ] Enclosed hexes calculated via point-in-triangle
- [ ] Territory collapses when corner city changes hands
- [ ] Multiple triangles create union territory
- [ ] Per-player independent territory
- [ ] Hex count exposed for supply system
- [ ] All unit tests pass (~11 tests)
