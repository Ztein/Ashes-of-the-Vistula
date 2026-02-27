extends BaseTest
## Unit tests for the TerritorySystem.

var _balance: Dictionary


func before_all() -> void:
	var loader := ConfigLoader.new()
	_balance = loader.load_balance()


func _make_city_at(id: int, pos: Vector2i, owner: int = 0) -> City:
	var city_data := {
		"id": id, "name": "City%d" % id, "tier": "hamlet",
		"production_type": "infantry", "hex_position": [pos.x, pos.y],
	}
	var city := City.new()
	city.init_from_config(city_data, _balance)
	city.owner_id = owner
	return city


# --- Triangle Detection ---

func test_no_territory_with_fewer_than_three_cities() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(5, 0), 0)
	# adjacency: [0,1]
	var triangles := system.find_triangles(0, [c0, c1], [[0, 1]])
	assert_empty(triangles, "need 3+ cities for triangles")


func test_no_territory_with_two_cities() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(5, 0), 0)
	var hexes := system.get_territory_hexes(0, [c0, c1], [[0, 1]], 100)
	assert_empty(hexes, "two cities form no territory")


func test_three_mutually_adjacent_cities_form_one_triangle() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 10), 0)
	var adj := [[0, 1], [1, 2], [0, 2]]
	var triangles := system.find_triangles(0, [c0, c1, c2], adj)
	assert_eq(triangles.size(), 1, "should find exactly one triangle")


func test_three_cities_not_all_mutually_adjacent_form_no_triangle() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 10), 0)
	# Missing edge 0-2
	var adj := [[0, 1], [1, 2]]
	var triangles := system.find_triangles(0, [c0, c1, c2], adj)
	assert_empty(triangles, "not all mutually adjacent = no triangle")


func test_triangle_encloses_hexes_inside_its_area() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 10), 0)
	var adj := [[0, 1], [1, 2], [0, 2]]
	var hexes := system.get_territory_hexes(0, [c0, c1, c2], adj, 200)
	assert_not_empty(hexes, "triangle should enclose hexes")


func test_triangle_does_not_include_hexes_outside() -> void:
	var system := TerritorySystem.new()
	# Small triangle at top-left
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(4, 0), 0)
	var c2 := _make_city_at(2, Vector2i(2, 4), 0)
	var adj := [[0, 1], [1, 2], [0, 2]]
	var hexes := system.get_territory_hexes(0, [c0, c1, c2], adj, 200)

	# A hex far outside should not be included
	var far_hex := Vector2i(15, 15)
	var found_far := false
	for h in hexes:
		if h == far_hex:
			found_far = true
			break
	assert_false(found_far, "hex at (15,15) should be outside small triangle")


func test_multiple_triangles_produce_union_territory() -> void:
	var system := TerritorySystem.new()
	# Two triangles sharing an edge
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 8), 0)
	var c3 := _make_city_at(3, Vector2i(5, -8), 0)
	var adj := [[0, 1], [1, 2], [0, 2], [0, 3], [1, 3]]
	var hexes_two := system.get_territory_hexes(0, [c0, c1, c2, c3], adj, 200)

	# Should have more territory than just one triangle
	var hexes_one := system.get_territory_hexes(0, [c0, c1, c2], [[0, 1], [1, 2], [0, 2]], 200)
	assert_gte(hexes_two.size(), hexes_one.size(), "two triangles should have >= territory of one")


func test_territory_collapses_when_corner_city_captured_by_enemy() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 10), 0)
	var adj := [[0, 1], [1, 2], [0, 2]]

	var hexes_before := system.get_territory_hexes(0, [c0, c1, c2], adj, 200)
	assert_not_empty(hexes_before, "should have territory before capture")

	# Enemy captures c2
	c2.owner_id = 1
	var hexes_after := system.get_territory_hexes(0, [c0, c1, c2], adj, 200)
	assert_empty(hexes_after, "territory should collapse")


func test_different_players_have_independent_territory() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 10), 0)
	var c3 := _make_city_at(3, Vector2i(15, 5), 1)
	var c4 := _make_city_at(4, Vector2i(20, 5), 1)
	var c5 := _make_city_at(5, Vector2i(17, 10), 1)
	var adj := [[0, 1], [1, 2], [0, 2], [3, 4], [4, 5], [3, 5]]
	var all_cities := [c0, c1, c2, c3, c4, c5]

	var p0_hexes := system.get_territory_hexes(0, all_cities, adj, 200)
	var p1_hexes := system.get_territory_hexes(1, all_cities, adj, 200)

	assert_not_empty(p0_hexes, "player 0 has territory")
	assert_not_empty(p1_hexes, "player 1 has territory")


func test_non_adjacent_cities_never_form_triangles() -> void:
	var system := TerritorySystem.new()
	var c0 := _make_city_at(0, Vector2i(0, 0), 0)
	var c1 := _make_city_at(1, Vector2i(10, 0), 0)
	var c2 := _make_city_at(2, Vector2i(5, 10), 0)
	# No adjacency at all
	var triangles := system.find_triangles(0, [c0, c1, c2], [])
	assert_empty(triangles, "no adjacency = no triangles")
