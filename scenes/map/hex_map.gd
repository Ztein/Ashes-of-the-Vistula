extends Node2D
## Renders the game map: adjacency lines, territory overlay, cities, stacks,
## combat indicators (siege/battle), and fog of war.

signal city_clicked(city_id: int)

const HEX_SCALE: float = 64.0
const CITY_SIZES := {"hamlet": 12.0, "village": 18.0, "major_city": 24.0}
const HUMAN_PLAYER_ID: int = 0

var _game_state: GameState
var _adjacency: Array = []
var _city_positions: Dictionary = {}  # city_id -> Vector2
var _player_colors: Dictionary = {}
var _selected_city_id: int = -1
var _selected_stack_id: int = -1
var _fog_enabled: bool = true
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta


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


func set_fog_enabled(enabled: bool) -> void:
	_fog_enabled = enabled


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
	_draw_fog_background()
	_draw_territory()
	_draw_adjacency()
	_draw_cities()
	_draw_combat_indicators()
	_draw_selection_highlight()
	_draw_stacks()


# --- Fog of War ---

func _get_visible_hexes() -> Dictionary:
	## Returns a set of hex positions (Vector2i) visible to the human player.
	## Visibility comes from: owned cities, adjacent hexes to owned cities,
	## and territory hexes.
	var visible: Dictionary = {}
	var ts := TerritorySystem.new()
	var all_cities := _game_state.get_all_cities()

	# Own cities + adjacency radius
	for city in all_cities:
		if city.owner_id == HUMAN_PLAYER_ID:
			var hex_pos: Array = []
			for cid in _city_positions:
				var c := _game_state.get_city(cid)
				if c != null and c.id == city.id:
					hex_pos = [city.hex_position.x, city.hex_position.y] if city.get("hex_position") else []
			# Mark city hex and surrounding hexes visible
			var city_pixel: Vector2 = _city_positions.get(city.id, Vector2.ZERO)
			var cx: int = roundi(city_pixel.x / HEX_SCALE)
			var cy: int = roundi(city_pixel.y / HEX_SCALE)
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					visible[Vector2i(cx + dx, cy + dy)] = true

	# Stacks provide vision around their position
	for stack in _game_state.get_all_stacks():
		var s: UnitStack = stack as UnitStack
		if s.owner_id != HUMAN_PLAYER_ID:
			continue
		var pixel_pos: Vector2
		if s.is_moving and _city_positions.has(s.city_id) and _city_positions.has(s.move_target_city_id):
			var from: Vector2 = _city_positions[s.city_id]
			var to: Vector2 = _city_positions[s.move_target_city_id]
			pixel_pos = from.lerp(to, s.move_progress)
		elif _city_positions.has(s.city_id):
			pixel_pos = _city_positions[s.city_id]
		else:
			continue
		var sx: int = roundi(pixel_pos.x / HEX_SCALE)
		var sy: int = roundi(pixel_pos.y / HEX_SCALE)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				visible[Vector2i(sx + dx, sy + dy)] = true

	# Territory hexes
	var territory_hexes := ts.get_territory_hexes(HUMAN_PLAYER_ID, all_cities, _adjacency, 200)
	for hex in territory_hexes:
		visible[Vector2i(hex.x, hex.y)] = true

	return visible


func _is_city_visible(city_id: int) -> bool:
	if not _fog_enabled:
		return true
	if _game_state == null:
		return true
	var city := _game_state.get_city(city_id)
	if city == null:
		return true
	# Own cities always visible
	if city.owner_id == HUMAN_PLAYER_ID:
		return true
	# Check if any of our stacks are at or near this city
	for stack in _game_state.get_all_stacks():
		var s: UnitStack = stack as UnitStack
		if s.owner_id == HUMAN_PLAYER_ID and s.city_id == city_id and not s.is_moving:
			return true
	# Check if adjacent to one of our cities
	for own_city in _game_state.get_all_cities():
		if own_city.owner_id == HUMAN_PLAYER_ID:
			if _cities_adjacent(own_city.id, city_id):
				return true
	return false


func _cities_adjacent(a: int, b: int) -> bool:
	for edge in _adjacency:
		var e0: int = int(edge[0])
		var e1: int = int(edge[1])
		if (e0 == a and e1 == b) or (e0 == b and e1 == a):
			return true
	return false


func _draw_fog_background() -> void:
	if not _fog_enabled:
		return
	# Draw a dim overlay over the entire map area, then territory/visibility
	# will be drawn on top. This creates fog effect for unseen areas.
	# Compute fog rect from actual city positions
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for pos in _city_positions.values():
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	var pad := HEX_SCALE * 2.0
	var map_rect := Rect2(min_pos.x - pad, min_pos.y - pad, max_pos.x - min_pos.x + pad * 2, max_pos.y - min_pos.y + pad * 2)
	draw_rect(map_rect, Color(0.0, 0.0, 0.0, 0.3))


# --- Territory ---

func _draw_territory() -> void:
	var all_cities := _game_state.get_all_cities()
	var ts := TerritorySystem.new()
	for player_id in _player_colors:
		var color: Color = _player_colors[player_id]
		var overlay := Color(color.r, color.g, color.b, 0.12)
		# Brighter overlay for own territory to counteract fog
		if player_id == HUMAN_PLAYER_ID and _fog_enabled:
			overlay = Color(color.r, color.g, color.b, 0.18)
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
			var vis_a := _is_city_visible(a)
			var vis_b := _is_city_visible(b)
			var line_alpha: float = 0.4 if (vis_a and vis_b) else 0.15
			draw_line(_city_positions[a], _city_positions[b], Color(0.5, 0.5, 0.5, line_alpha), 1.5)


# --- Cities ---

func _draw_cities() -> void:
	var font := ThemeDB.fallback_font
	for city in _game_state.get_all_cities():
		var pos: Vector2 = _city_positions[city.id]
		var radius: float = CITY_SIZES.get(city.tier, 12.0)
		var visible := _is_city_visible(city.id)
		var color := _get_owner_color(city.owner_id)

		if not visible:
			# Fog: show city but dimmed, hide owner color
			color = Color(0.35, 0.35, 0.35)

		# Fill + outline
		draw_circle(pos, radius, color)
		var outline_alpha: float = 0.8 if visible else 0.3
		draw_arc(pos, radius, 0, TAU, 32, Color(1, 1, 1, outline_alpha), 1.5)

		# City name below
		var name_alpha: float = 1.0 if visible else 0.4
		var name_size := font.get_string_size(city.city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, pos + Vector2(-name_size.x / 2, radius + 14),
			city.city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, name_alpha))

		# Structure HP bar — always shown for visible cities
		if visible:
			var bw: float = maxf(radius * 2.5, 30.0)
			var bp := pos + Vector2(-bw / 2.0, -radius - 10)
			var pct: float = city.structure_hp / city.max_structure_hp if city.max_structure_hp > 0 else 0.0
			draw_rect(Rect2(bp, Vector2(bw, 5)), Color(0.2, 0.2, 0.2, 0.8))
			var bar_color: Color
			if pct > 0.6:
				bar_color = Color(0.0, 0.8, 0.0, 0.8)
			elif pct > 0.3:
				bar_color = Color(0.9, 0.7, 0.0, 0.8)
			else:
				bar_color = Color(0.9, 0.2, 0.0, 0.8)
			draw_rect(Rect2(bp, Vector2(bw * pct, 5)), bar_color)
			# HP text above bar
			var hp_text := "%d/%d" % [roundi(city.structure_hp), roundi(city.max_structure_hp)]
			var hp_size := font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
			draw_string(font, bp + Vector2((bw - hp_size.x) / 2.0, -2),
				hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.7))


# --- Combat Indicators ---

func _draw_combat_indicators() -> void:
	for city in _game_state.get_all_cities():
		var pos: Vector2 = _city_positions[city.id]
		var radius: float = CITY_SIZES.get(city.tier, 12.0)

		if _game_state.is_city_in_battle(city.id):
			# Battle: red pulsing ring
			var pulse: float = 0.5 + 0.5 * sin(_elapsed * 6.0)
			var battle_color := Color(1.0, 0.2, 0.0, 0.5 + pulse * 0.5)
			draw_arc(pos, radius + 6.0, 0, TAU, 32, battle_color, 3.0)
			# Crossed swords indicator (text-based)
			var font := ThemeDB.fallback_font
			draw_string(font, pos + Vector2(-6, -radius - 12), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)

		elif _game_state.is_city_under_siege(city.id):
			# Siege: orange pulsing ring
			var pulse: float = 0.5 + 0.5 * sin(_elapsed * 3.0)
			var siege_color := Color(1.0, 0.6, 0.0, 0.3 + pulse * 0.4)
			draw_arc(pos, radius + 5.0, 0, TAU, 32, siege_color, 2.5)


func _draw_selection_highlight() -> void:
	if _selected_city_id < 0 or not _city_positions.has(_selected_city_id):
		return
	var city := _game_state.get_city(_selected_city_id)
	if city == null:
		return
	var pos: Vector2 = _city_positions[_selected_city_id]
	var radius: float = CITY_SIZES.get(city.tier, 12.0) + 4.0
	draw_arc(pos, radius, 0, TAU, 32, Color.YELLOW, 2.5)


# --- Stacks ---

func _draw_stacks() -> void:
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
			var s: UnitStack = stacks[i] as UnitStack
			# In fog, hide enemy stacks
			if _fog_enabled and s.owner_id != HUMAN_PLAYER_ID and not _is_city_visible(city_id):
				continue
			var offset_x: float = (float(i) - float(stacks.size() - 1) / 2.0) * 28.0
			var base: Vector2 = _city_positions[city_id]
			var pos: Vector2 = base + Vector2(offset_x, -28)
			_draw_stack_indicator(s, pos)


func _draw_moving_stack(stack: UnitStack) -> void:
	# In fog, hide enemy moving stacks unless both endpoints visible
	if _fog_enabled and stack.owner_id != HUMAN_PLAYER_ID:
		if not _is_city_visible(stack.city_id) and not _is_city_visible(stack.move_target_city_id):
			return
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
