extends BaseTest
## Integration tests for JSON configuration loading.

var _loader: ConfigLoader


func before_each() -> void:
	_loader = ConfigLoader.new()


func test_balance_json_loads_successfully() -> void:
	var data := _loader.load_balance()
	assert_not_empty(data, "balance.json should load as non-empty Dictionary")


func test_balance_has_all_required_top_level_keys() -> void:
	var data := _loader.load_balance()
	assert_true(data.has("units"), "balance should have 'units'")
	assert_true(data.has("cities"), "balance should have 'cities'")
	assert_true(data.has("supply"), "balance should have 'supply'")
	assert_true(data.has("command"), "balance should have 'command'")
	assert_true(data.has("dominance"), "balance should have 'dominance'")
	assert_true(data.has("simulation"), "balance should have 'simulation'")


func test_balance_has_all_three_unit_types() -> void:
	var data := _loader.load_balance()
	var units: Dictionary = data["units"]
	assert_true(units.has("infantry"), "units should have 'infantry'")
	assert_true(units.has("cavalry"), "units should have 'cavalry'")
	assert_true(units.has("artillery"), "units should have 'artillery'")


func test_balance_has_all_three_city_tiers() -> void:
	var data := _loader.load_balance()
	var cities: Dictionary = data["cities"]
	assert_true(cities.has("hamlet"), "cities should have 'hamlet'")
	assert_true(cities.has("village"), "cities should have 'village'")
	assert_true(cities.has("major_city"), "cities should have 'major_city'")


func test_balance_unit_has_required_fields() -> void:
	var data := _loader.load_balance()
	var infantry: Dictionary = data["units"]["infantry"]
	assert_true(infantry.has("hp"), "infantry should have 'hp'")
	assert_true(infantry.has("dps"), "infantry should have 'dps'")
	assert_true(infantry.has("siege_damage"), "infantry should have 'siege_damage'")
	assert_true(infantry.has("speed"), "infantry should have 'speed'")
	assert_true(infantry.has("production_time"), "infantry should have 'production_time'")


func test_balance_city_has_required_fields() -> void:
	var data := _loader.load_balance()
	var hamlet: Dictionary = data["cities"]["hamlet"]
	assert_true(hamlet.has("local_cap"), "hamlet should have 'local_cap'")
	assert_true(hamlet.has("structure_hp"), "hamlet should have 'structure_hp'")
	assert_true(hamlet.has("production_interval"), "hamlet should have 'production_interval'")
	assert_true(hamlet.has("structure_regen_rate"), "hamlet should have 'structure_regen_rate'")


func test_map_json_loads_successfully() -> void:
	var data := _loader.load_map()
	assert_not_empty(data, "map.json should load as non-empty Dictionary")


func test_map_has_expected_city_count() -> void:
	var data := _loader.load_map()
	var cities: Array = data["cities"]
	assert_eq(cities.size(), 15, "map should have 15 cities")


func test_map_has_adjacency_data() -> void:
	var data := _loader.load_map()
	var adjacency: Array = data["adjacency"]
	assert_gt(adjacency.size(), 0, "map should have adjacency connections")


func test_map_cities_have_required_fields() -> void:
	var data := _loader.load_map()
	var city: Dictionary = data["cities"][0]
	assert_true(city.has("id"), "city should have 'id'")
	assert_true(city.has("name"), "city should have 'name'")
	assert_true(city.has("tier"), "city should have 'tier'")
	assert_true(city.has("production_type"), "city should have 'production_type'")
	assert_true(city.has("hex_position"), "city should have 'hex_position'")


func test_scenario_json_loads_successfully() -> void:
	var data := _loader.load_scenario()
	assert_not_empty(data, "scenario.json should load as non-empty Dictionary")


func test_scenario_has_two_players() -> void:
	var data := _loader.load_scenario()
	var players: Array = data["players"]
	assert_eq(players.size(), 2, "scenario should have 2 players")


func test_scenario_has_city_ownership() -> void:
	var data := _loader.load_scenario()
	var ownership: Dictionary = data["city_ownership"]
	assert_not_empty(ownership, "scenario should have city_ownership")


func test_scenario_has_starting_stacks() -> void:
	var data := _loader.load_scenario()
	assert_true(data.has("starting_stacks"), "scenario should have 'starting_stacks'")
	var stacks: Array = data["starting_stacks"]
	assert_gt(stacks.size(), 0, "scenario should have at least one starting stack")


func test_missing_file_returns_empty_dictionary() -> void:
	var data := _loader.load_balance("res://data/nonexistent.json")
	assert_empty(data, "missing file should return empty Dictionary")


func test_invalid_json_returns_empty_dictionary() -> void:
	# Write a temporary invalid JSON file
	var temp_path := "res://data/_test_invalid.json"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file:
		file.store_string("{invalid json content")
		file.close()

	var data := _loader.load_balance(temp_path)
	assert_empty(data, "invalid JSON should return empty Dictionary")

	# Clean up temp file
	DirAccess.remove_absolute(temp_path)
