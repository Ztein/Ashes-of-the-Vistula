extends Node2D
## Main game controller. Wires simulation to presentation.
## Handles: tick timer, camera, player input, command translation, AI, admin panel.

const PLAYER_ID: int = 0  # Human player
const AI_PLAYER_ID: int = 1
const TICK_RATE: float = 10.0

var _game_state: GameState
var _ai: AIController
var _loader := ConfigLoader.new()
var _map_data: Dictionary = {}
var _scenario_data: Dictionary = {}
var _balance: Dictionary = {}
var _tick_timer: float = 0.0
var _tick_count: int = 0
var _camera_speed: float = 400.0
var _map_bounds: Rect2 = Rect2()  # Bounding box of all cities (with padding)
var _paused: bool = false

@onready var _hex_map: Node2D = $HexMap
@onready var _camera: Camera2D = $Camera2D
@onready var _stack_info: PanelContainer = $UILayer/StackInfo
@onready var _hud: Control = $UILayer/HUD
@onready var _admin_panel: PanelContainer = $UILayer/AdminPanel
@onready var _combat_info: PanelContainer = $UILayer/CombatInfo
@onready var _game_over_overlay: PanelContainer = $UILayer/GameOverOverlay
@onready var _game_menu: PanelContainer = $UILayer/GameMenu


func _ready() -> void:
	_balance = GameConfig.get_balance()
	_map_data = _loader.load_map()
	_scenario_data = _loader.load_scenario()

	if _map_data.is_empty() or _scenario_data.is_empty() or _balance.is_empty():
		push_error("Game: failed to load data files")
		return

	_init_game()

	# Admin panel signals
	_admin_panel.reset_requested.connect(_on_reset_requested)
	_admin_panel.balance_changed.connect(_on_balance_changed)

	# Game over overlay signals
	_game_over_overlay.restart_requested.connect(_on_reset_requested)
	_game_over_overlay.menu_requested.connect(_on_menu_requested)

	# Game menu signals
	_game_menu.resume_requested.connect(_on_menu_resume)
	_game_menu.restart_requested.connect(_on_menu_restart)
	_game_menu.give_up_confirmed.connect(_on_give_up)
	_game_menu.quit_requested.connect(_on_menu_requested)


func _init_game() -> void:
	_game_state = GameState.new()
	_game_state.initialize(_map_data, _scenario_data, _balance)

	_hex_map.setup(_game_state, _map_data, _scenario_data)
	_hex_map.city_clicked.connect(_on_city_clicked)
	_hex_map.stack_double_clicked.connect(_on_stack_double_clicked)
	_hex_map.right_clicked.connect(_on_right_clicked)

	_game_state.city_captured.connect(_on_city_captured)
	_game_state.siege_started.connect(_on_siege_started)
	_game_state.battle_started.connect(_on_battle_started)
	_game_state.victory_achieved.connect(_on_victory)
	_game_state.production_completed.connect(_on_production_completed)
	_game_state.stack_arrived.connect(_on_stack_arrived)

	_stack_info.visible = false
	_combat_info.visible = false
	_game_over_overlay.visible = false

	# Initialize AI opponent
	_ai = AIController.new()
	_ai.setup(AI_PLAYER_ID, _game_state, _balance)

	# Admin panel setup
	_admin_panel.setup(_balance, _game_state)
	_admin_panel.visible = false

	# Reset tick state
	_tick_timer = 0.0
	_tick_count = 0
	_selected_city_id = -1
	_selected_stack_id = -1

	# Fit camera to show all cities
	_fit_camera_to_map()
	_hex_map.queue_redraw()


func _process(delta: float) -> void:
	if _game_state == null:
		return

	_handle_camera(delta)

	if not _paused and not _game_state.is_game_over():
		_tick_simulation(delta)

	# Update admin panel state display every frame if visible
	if _admin_panel.visible:
		_admin_panel.update_state_display()


func _tick_simulation(delta: float) -> void:
	_tick_timer += delta
	var tick_interval: float = 1.0 / TICK_RATE
	while _tick_timer >= tick_interval:
		_tick_timer -= tick_interval

		# AI evaluation
		if _ai != null and _ai.should_evaluate(_tick_count):
			_ai.evaluate()
			for cmd in _ai.get_pending_commands():
				_game_state.submit_command(cmd)

		_game_state.tick()
		_tick_count += 1
		_clear_stale_selection()
		_hex_map.queue_redraw()
		_update_hud()
		_update_combat_info()


func _fit_camera_to_map() -> void:
	## Compute bounding box of all cities and center/zoom camera to fit.
	var cities := _game_state.get_all_cities()
	if cities.is_empty():
		_camera.position = Vector2(640, 480)
		return

	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for city in cities:
		var pixel_pos: Vector2 = _hex_map.get_city_pixel_pos(city.id)
		min_pos.x = minf(min_pos.x, pixel_pos.x)
		min_pos.y = minf(min_pos.y, pixel_pos.y)
		max_pos.x = maxf(max_pos.x, pixel_pos.x)
		max_pos.y = maxf(max_pos.y, pixel_pos.y)

	var padding := 100.0
	min_pos -= Vector2(padding, padding)
	max_pos += Vector2(padding, padding)
	_map_bounds = Rect2(min_pos, max_pos - min_pos)

	# Center camera on the map
	_camera.position = _map_bounds.get_center()

	# Zoom to fit all cities in the viewport
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_x: float = viewport_size.x / _map_bounds.size.x
	var zoom_y: float = viewport_size.y / _map_bounds.size.y
	var fit_zoom: float = minf(zoom_x, zoom_y)
	fit_zoom = clampf(fit_zoom, 0.3, 3.0)
	_camera.zoom = Vector2(fit_zoom, fit_zoom)


func _handle_camera(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move.y += 1

	if move != Vector2.ZERO:
		_camera.position += move.normalized() * _camera_speed * delta

	# Clamp camera to map bounds
	if _map_bounds.size.length() > 0:
		_camera.position.x = clampf(_camera.position.x, _map_bounds.position.x, _map_bounds.end.x)
		_camera.position.y = clampf(_camera.position.y, _map_bounds.position.y, _map_bounds.end.y)


func _unhandled_input(event: InputEvent) -> void:
	if _game_state == null:
		return

	# Mouse input
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x * 1.1, 0.3, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = Vector2.ONE * clampf(_camera.zoom.x * 0.9, 0.3, 3.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_deselect_all()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			# Click on empty space (not on a city) — deselect
			_deselect_all()

	# Keyboard commands
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F12:
				_admin_panel.visible = not _admin_panel.visible
			KEY_F:
				_try_siege()
			KEY_G:
				_try_capture_neutral()
			KEY_R:
				_try_split()
			KEY_TAB:
				_cycle_stack_at_city()
			KEY_ESCAPE:
				_toggle_game_menu()


# --- Selection ---

var _selected_city_id: int = -1
var _selected_stack_id: int = -1


func _on_city_clicked(city_id: int) -> void:
	if _game_state == null or _game_state.is_game_over() or _paused:
		return

	# If a stack is selected and we click a different adjacent city, issue move
	if _selected_stack_id >= 0 and city_id != _selected_city_id:
		var stack := _game_state.get_stack(_selected_stack_id)
		if stack != null and not stack.is_moving:
			var result := _game_state.submit_command({
				"type": "move_stack",
				"player_id": PLAYER_ID,
				"stack_id": _selected_stack_id,
				"target_city_id": city_id,
			})
			if result:
				_deselect_all()
				_hex_map.queue_redraw()
				return

	# Clicking the same city — cycle through stacks or toggle deselect
	if city_id == _selected_city_id and _selected_stack_id >= 0:
		var stacks := _game_state.get_stacks_at_city(PLAYER_ID, city_id)
		if stacks.size() > 1:
			# Find current stack index and cycle to next
			var current_idx: int = -1
			for i in range(stacks.size()):
				if (stacks[i] as UnitStack).id == _selected_stack_id:
					current_idx = i
					break
			var next_idx: int = (current_idx + 1) % stacks.size()
			if next_idx == 0 and current_idx >= 0:
				# Cycled back to first — deselect
				_deselect_all()
			else:
				_selected_stack_id = (stacks[next_idx] as UnitStack).id
				_hex_map.set_selection(_selected_city_id, _selected_stack_id)
				_hex_map.queue_redraw()
				_update_stack_info()
		else:
			# Only one stack — clicking again deselects
			_deselect_all()
		return

	# Select the city and the first player stack there
	_selected_city_id = city_id
	_selected_stack_id = -1

	var stacks := _game_state.get_stacks_at_city(PLAYER_ID, city_id)
	if not stacks.is_empty():
		_selected_stack_id = (stacks[0] as UnitStack).id

	_hex_map.set_selection(_selected_city_id, _selected_stack_id)
	_hex_map.queue_redraw()
	_update_stack_info()
	_update_combat_info()


func _on_stack_double_clicked(city_id: int) -> void:
	if _game_state == null or _game_state.is_game_over() or _paused:
		return
	# Double-click on a city halves the currently selected stack
	if _selected_stack_id >= 0 and _selected_city_id == city_id:
		_try_split()


func _on_right_clicked() -> void:
	_deselect_all()


func _clear_stale_selection() -> void:
	if _selected_stack_id < 0:
		return
	var stack := _game_state.get_stack(_selected_stack_id)
	if stack == null or stack.is_empty():
		_selected_stack_id = -1
		_hex_map.set_selection(_selected_city_id, -1)
		_stack_info.visible = false


func _deselect_all() -> void:
	_selected_city_id = -1
	_selected_stack_id = -1
	_hex_map.set_selection(-1, -1)
	_hex_map.queue_redraw()
	_stack_info.visible = false
	_combat_info.visible = false


func _cycle_stack_at_city() -> void:
	if _selected_city_id < 0:
		return
	var stacks := _game_state.get_stacks_at_city(PLAYER_ID, _selected_city_id)
	if stacks.size() <= 1:
		return
	var current_idx: int = -1
	for i in range(stacks.size()):
		if (stacks[i] as UnitStack).id == _selected_stack_id:
			current_idx = i
			break
	_selected_stack_id = (stacks[(current_idx + 1) % stacks.size()] as UnitStack).id
	_hex_map.set_selection(_selected_city_id, _selected_stack_id)
	_hex_map.queue_redraw()
	_update_stack_info()


# --- Commands ---

func _try_siege() -> void:
	if _selected_stack_id < 0 or _game_state.is_game_over():
		return
	_game_state.submit_command({
		"type": "start_siege",
		"player_id": PLAYER_ID,
		"stack_id": _selected_stack_id,
	})
	_hex_map.queue_redraw()


func _try_capture_neutral() -> void:
	if _selected_stack_id < 0 or _game_state.is_game_over():
		return
	_game_state.submit_command({
		"type": "capture_neutral",
		"player_id": PLAYER_ID,
		"stack_id": _selected_stack_id,
	})
	_hex_map.queue_redraw()


func _try_split() -> void:
	if _selected_stack_id < 0 or _game_state.is_game_over():
		return
	var stack := _game_state.get_stack(_selected_stack_id)
	if stack == null or stack.count <= 1:
		return
	_game_state.submit_command({
		"type": "split_stack",
		"player_id": PLAYER_ID,
		"stack_id": _selected_stack_id,
	})
	_hex_map.queue_redraw()
	_update_stack_info()


# --- UI Updates ---

func _update_stack_info() -> void:
	if _selected_stack_id < 0:
		_stack_info.visible = false
		return
	var stack := _game_state.get_stack(_selected_stack_id)
	if stack == null or stack.is_empty():
		_stack_info.visible = false
		return

	_stack_info.visible = true
	_stack_info.update_display(stack, _balance)


func _update_hud() -> void:
	if _hud == null or not _hud.has_method("update_display"):
		return
	var cmd_info := _game_state.get_command_info(PLAYER_ID)
	var supply_info := _game_state.get_supply_info(PLAYER_ID)
	_hud.update_display(cmd_info, supply_info, _game_state)


func _update_combat_info() -> void:
	if _combat_info == null:
		return
	_combat_info.update_display(_selected_city_id, _game_state, _balance)


# --- Signal Handlers ---

func _on_city_captured(_city_id: int, _new_owner: int) -> void:
	_hex_map.queue_redraw()
	_update_combat_info()


func _on_siege_started(_city_id: int, _attacker: int) -> void:
	_hex_map.queue_redraw()
	_update_combat_info()


func _on_battle_started(_city_id: int) -> void:
	_hex_map.queue_redraw()
	_update_combat_info()


func _on_victory(winner_id: int) -> void:
	_hex_map.queue_redraw()
	_update_hud()
	if winner_id == PLAYER_ID:
		_game_over_overlay.show_victory()
	else:
		_game_over_overlay.show_defeat()


func _on_production_completed(_city_id: int, _unit_type: String) -> void:
	_hex_map.queue_redraw()


func _on_stack_arrived(_stack_id: int, _city_id: int) -> void:
	_hex_map.queue_redraw()


# --- Admin/Reset ---

func _on_reset_requested() -> void:
	_game_over_overlay.visible = false
	_game_menu.hide_menu()
	_paused = false
	# Disconnect old signals
	if _game_state != null:
		if _game_state.city_captured.is_connected(_on_city_captured):
			_game_state.city_captured.disconnect(_on_city_captured)
		if _game_state.siege_started.is_connected(_on_siege_started):
			_game_state.siege_started.disconnect(_on_siege_started)
		if _game_state.battle_started.is_connected(_on_battle_started):
			_game_state.battle_started.disconnect(_on_battle_started)
		if _game_state.victory_achieved.is_connected(_on_victory):
			_game_state.victory_achieved.disconnect(_on_victory)
		if _game_state.production_completed.is_connected(_on_production_completed):
			_game_state.production_completed.disconnect(_on_production_completed)
		if _game_state.stack_arrived.is_connected(_on_stack_arrived):
			_game_state.stack_arrived.disconnect(_on_stack_arrived)
	if _hex_map.city_clicked.is_connected(_on_city_clicked):
		_hex_map.city_clicked.disconnect(_on_city_clicked)
	if _hex_map.stack_double_clicked.is_connected(_on_stack_double_clicked):
		_hex_map.stack_double_clicked.disconnect(_on_stack_double_clicked)
	if _hex_map.right_clicked.is_connected(_on_right_clicked):
		_hex_map.right_clicked.disconnect(_on_right_clicked)

	# Clear hex map children (click areas)
	for child in _hex_map.get_children():
		child.queue_free()

	_init_game()


func _on_balance_changed(new_balance: Dictionary) -> void:
	_balance = new_balance
	_on_reset_requested()


func _on_menu_requested() -> void:
	_paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Game Menu ---

func _toggle_game_menu() -> void:
	if _game_state != null and _game_state.is_game_over():
		return
	if _game_menu.visible:
		_game_menu.hide_menu()
		_paused = false
	else:
		_deselect_all()
		_game_menu.show_menu()
		_paused = true


func _on_menu_resume() -> void:
	_game_menu.hide_menu()
	_paused = false


func _on_menu_restart() -> void:
	_game_menu.hide_menu()
	_paused = false
	_on_reset_requested()


func _on_give_up() -> void:
	_paused = false
	# Trigger victory for the opponent
	_on_victory(AI_PLAYER_ID)
