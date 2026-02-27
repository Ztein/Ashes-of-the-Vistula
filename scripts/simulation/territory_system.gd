class_name TerritorySystem
extends RefCounted
## Detects territory from triangles of mutually-adjacent same-owner cities.
## Enclosed hexes are calculated via point-in-triangle tests.


func find_triangles(player_id: int, cities: Array, adjacency: Array) -> Array:
	## Returns array of [city_id_a, city_id_b, city_id_c] triples where
	## all three cities are owned by player_id and mutually adjacent.
	var owned_ids: Array[int] = []
	for city_obj in cities:
		var city: City = city_obj as City
		if city.owner_id == player_id:
			owned_ids.append(city.id)

	if owned_ids.size() < 3:
		return []

	# Build adjacency set for O(1) lookup
	var adj_set := {}
	for edge in adjacency:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		var key_ab := _edge_key(a, b)
		adj_set[key_ab] = true

	# Find all triangles
	var result: Array = []
	for i in range(owned_ids.size()):
		for j in range(i + 1, owned_ids.size()):
			for k in range(j + 1, owned_ids.size()):
				var a := owned_ids[i]
				var b := owned_ids[j]
				var c := owned_ids[k]
				if adj_set.has(_edge_key(a, b)) and adj_set.has(_edge_key(b, c)) and adj_set.has(_edge_key(a, c)):
					result.append([a, b, c])

	return result


func get_territory_hexes(player_id: int, cities: Array, adjacency: Array, total_hex_count: int) -> Array:
	## Returns array of Vector2i hex positions enclosed by the player's triangles.
	var triangles := find_triangles(player_id, cities, adjacency)
	if triangles.is_empty():
		return []

	# Build city id -> position lookup
	var city_pos := {}
	for city_obj in cities:
		var city: City = city_obj as City
		city_pos[city.id] = city.hex_position

	# Determine bounding box of all triangle vertices
	var min_x: int = 999999
	var min_y: int = 999999
	var max_x: int = -999999
	var max_y: int = -999999

	for tri in triangles:
		for city_id in tri:
			var pos: Vector2i = city_pos[city_id]
			min_x = mini(min_x, pos.x)
			min_y = mini(min_y, pos.y)
			max_x = maxi(max_x, pos.x)
			max_y = maxi(max_y, pos.y)

	# Check each hex in the bounding box
	var enclosed: Array = []
	var seen := {}

	for tri in triangles:
		var p0: Vector2 = Vector2(city_pos[tri[0]])
		var p1: Vector2 = Vector2(city_pos[tri[1]])
		var p2: Vector2 = Vector2(city_pos[tri[2]])

		for x in range(min_x, max_x + 1):
			for y in range(min_y, max_y + 1):
				var hex := Vector2i(x, y)
				if seen.has(hex):
					continue
				var point := Vector2(float(x), float(y))
				if _point_in_triangle(point, p0, p1, p2):
					enclosed.append(hex)
					seen[hex] = true

	return enclosed


func get_territory_hex_count(player_id: int, cities: Array, adjacency: Array, total_hex_count: int) -> int:
	return get_territory_hexes(player_id, cities, adjacency, total_hex_count).size()


func is_hex_in_territory(hex: Vector2i, player_id: int, cities: Array, adjacency: Array, total_hex_count: int) -> bool:
	var hexes := get_territory_hexes(player_id, cities, adjacency, total_hex_count)
	return hex in hexes


func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	## Barycentric coordinate test for point-in-triangle.
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a

	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)

	var inv_denom := dot00 * dot11 - dot01 * dot01
	if absf(inv_denom) < 0.0001:
		return false  # Degenerate triangle
	inv_denom = 1.0 / inv_denom

	var u := (dot11 * dot02 - dot01 * dot12) * inv_denom
	var v := (dot00 * dot12 - dot01 * dot02) * inv_denom

	return u >= 0.0 and v >= 0.0 and (u + v) <= 1.0


func _edge_key(a: int, b: int) -> int:
	## Create a unique key for an undirected edge.
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return lo * 10000 + hi
