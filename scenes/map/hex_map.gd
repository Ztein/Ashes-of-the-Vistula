extends Node2D
## Renders the game map: adjacency lines, territory overlay, cities, and stacks.

signal city_clicked(city_id: int)

const HEX_SCALE: float = 64.0
const CITY_SIZES := {"hamlet": 12.0, "village": 18.0, "major_city": 24.0}

var _game_state: GameState
var _adjacency: Array = []
var _city_positions: Dictionary = {}  # city_id -> Vector2
var _player_colors: Dictionary = {}
var _selected_city_id: int = -1
var _selected_stack_id: int = -1


func setup(game_state: GameState, map_data: Dictionary, scenario_data: Dictionary) -> void:
	_game_state = game_state
	_adjacency = map_data.get("adjacency", [])

	for city_data in map_data.get("cities", []):
		var pos: Array = city_data["hex_position"]
		_city_positions[int(city_data["id"])] = Vector2(float(pos[0]) * HEX_SCALE, float(pos[1]) * HEX_SCALE)

	for player in scenario_data.get("players", []):
		var c: Array = player.get("color", [0.5, 0.5, 0.5, 1.0])
		_player_colors[int(player["id"])] = Color(c[0], c[1], c[2], c[3])

	_create_city_click_areas()


func set_selection(city_id: int, stack_id: int) -> void:
	_selected_city_id = city_id
	_selected_stack_id = stack_id


func get_city_pixel_pos(city_id: int) -> Vector2:
	return _city_positions.get(city_id, Vector2.ZERO)


func _create_city_click_areas() -> void:
	for city in _game_state.get_all_cities():
		var area := Area2D.new()
		area.position = _city_positions[city.id]
		area.input_pickable = true
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = CITY_SIZES.get(city.tier, 12.0) + 8.0
		shape.shape = circle
		area.add_child(shape)
		area.input_event.connect(_on_area_input.bind(city.id))
		add_child(area)


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, city_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		city_clicked.emit(city_id)


func _draw() -> void:
	if _game_state == null:
		return
	_draw_territory()
	_draw_adjacency()
	_draw_cities()
	_draw_selection_highlight()
	_draw_stacks()


func _draw_territory() -> void:
	var all_cities := _game_state.get_all_cities()
	var ts := TerritorySystem.new()
	for player_id in _player_colors:
		var color: Color = _player_colors[player_id]
		var overlay := Color(color.r, color.g, color.b, 0.12)
		var hexes := ts.get_territory_hexes(player_id, all_cities, _adjacency, 200)
		for hex in hexes:
			var p := Vector2(float(hex.x) * HEX_SCALE, float(hex.y) * HEX_SCALE)
			var s := HEX_SCALE * 0.45
			draw_rect(Rect2(p.x - s, p.y - s, s * 2, s * 2), overlay)


func _draw_adjacency() -> void:
	for edge in _adjacency:
		var a: int = int(edge[0])
		var b: int = int(edge[1])
		if _city_positions.has(a) and _city_positions.has(b):
			draw_line(_city_positions[a], _city_positions[b], Color(0.5, 0.5, 0.5, 0.4), 1.5)


func _draw_cities() -> void:
	var font := ThemeDB.fallback_font
	for city in _game_state.get_all_cities():
		var pos: Vector2 = _city_positions[city.id]
		var radius: float = CITY_SIZES.get(city.tier, 12.0)
		var color := _get_owner_color(city.owner_id)

		# Fill + outline
		draw_circle(pos, radius, color)
		draw_arc(pos, radius, 0, TAU, 32, Color(1, 1, 1, 0.8), 1.5)

		# City name below
		var name_size := font.get_string_size(city.city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, pos + Vector2(-name_size.x / 2, radius + 14),
			city.city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

		# Structure HP bar (only when damaged)
		if city.structure_hp < city.max_structure_hp:
			var bw: float = radius * 2.0
			var bp := pos + Vector2(-radius, -radius - 8)
			var pct: float = city.structure_hp / city.max_structure_hp
			draw_rect(Rect2(bp, Vector2(bw, 4)), Color(0.2, 0.2, 0.2, 0.8))
			draw_rect(Rect2(bp, Vector2(bw * pct, 4)), Color(0.0, 0.8, 0.0, 0.8))


func _draw_selection_highlight() -> void:
	if _selected_city_id < 0 or not _city_positions.has(_selected_city_id):
		return
	var city := _game_state.get_city(_selected_city_id)
	if city == null:
		return
	var pos: Vector2 = _city_positions[_selected_city_id]
	var radius: float = CITY_SIZES.get(city.tier, 12.0) + 4.0
	draw_arc(pos, radius, 0, TAU, 32, Color.YELLOW, 2.5)


func _draw_stacks() -> void:
	# Group stationary stacks by city for offset layout
	var by_city: Dictionary = {}
	for stack in _game_state.get_all_stacks():
		var s: UnitStack = stack as UnitStack
		if s.is_empty():
			continue
		if s.is_moving:
			_draw_moving_stack(s)
		else:
			if not by_city.has(s.city_id):
				by_city[s.city_id] = []
			by_city[s.city_id].append(s)

	for city_id in by_city:
		if not _city_positions.has(city_id):
			continue
		var stacks: Array = by_city[city_id]
		for i in range(stacks.size()):
			var offset_x: float = (float(i) - float(stacks.size() - 1) / 2.0) * 28.0
			var base: Vector2 = _city_positions[city_id]
			var pos: Vector2 = base + Vector2(offset_x, -28)
			_draw_stack_indicator(stacks[i], pos)


func _draw_moving_stack(stack: UnitStack) -> void:
	if not _city_positions.has(stack.city_id) or not _city_positions.has(stack.move_target_city_id):
		return
	var from: Vector2 = _city_positions[stack.city_id]
	var to: Vector2 = _city_positions[stack.move_target_city_id]
	var pos: Vector2 = from.lerp(to, stack.move_progress)
	_draw_stack_indicator(stack, pos)


func _draw_stack_indicator(stack: UnitStack, pos: Vector2) -> void:
	var color := _get_owner_color(stack.owner_id)
	var size := Vector2(24, 16)
	var rect := Rect2(pos - size / 2, size)

	# Selection highlight
	if stack.id == _selected_stack_id:
		draw_rect(Rect2(rect.position - Vector2(2, 2), rect.size + Vector2(4, 4)), Color.YELLOW, false, 2.0)

	draw_rect(rect, Color(color.r, color.g, color.b, 0.85))
	draw_rect(rect, Color.WHITE, false, 1.0)

	# Unit count
	var font := ThemeDB.fallback_font
	var text := str(stack.total_units())
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(font, pos + Vector2(-tw / 2, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


func _get_owner_color(owner_id: int) -> Color:
	if _player_colors.has(owner_id):
		return _player_colors[owner_id]
	return Color(0.5, 0.5, 0.5)
