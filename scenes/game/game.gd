extends Node2D
## Main game controller. Wires simulation to presentation.
## Handles: tick timer, camera, player input, command translation.

const PLAYER_ID: int = 0  # Human player
const TICK_RATE: float = 10.0

var _game_state: GameState
var _loader := ConfigLoader.new()
var _map_data: Dictionary = {}
var _scenario_data: Dictionary = {}
var _balance: Dictionary = {}
var _tick_timer: float = 0.0
var _camera_speed: float = 400.0

@onready var _hex_map: Node2D = $HexMap
@onready var _camera: Camera2D = $Camera2D
@onready var _stack_info: PanelContainer = $UILayer/StackInfo
@onready var _hud: Control = $UILayer/HUD


func _ready() -> void:
	_balance = GameConfig.get_balance()
	_map_data = _loader.load_map()
	_scenario_data = _loader.load_scenario()

	if _map_data.is_empty() or _scenario_data.is_empty() or _balance.is_empty():
		push_error("Game: failed to load data files")
		return

	_game_state = GameState.new()
	_game_state.initialize(_map_data, _scenario_data, _balance)

	_hex_map.setup(_game_state, _map_data, _scenario_data)
	_hex_map.city_clicked.connect(_on_city_clicked)

	_game_state.city_captured.connect(_on_city_captured)
	_game_state.siege_started.connect(_on_siege_started)
	_game_state.battle_started.connect(_on_battle_started)
	_game_state.victory_achieved.connect(_on_victory)
	_game_state.production_completed.connect(_on_production_completed)
	_game_state.stack_arrived.connect(_on_stack_arrived)

	_stack_info.visible = false

	# Center camera roughly on the map
	_camera.position = Vector2(640, 480)


func _process(delta: float) -> void:
	if _game_state == null or _game_state.is_game_over():
		return

	_handle_camera(delta)
	_tick_simulation(delta)


func _tick_simulation(delta: float) -> void:
	_tick_timer += delta
	var tick_interval: float = 1.0 / TICK_RATE
	while _tick_timer >= tick_interval:
		_tick_timer -= tick_interval
		_game_state.tick()
		_hex_map.queue_redraw()
		_update_hud()


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


func _unhandled_input(event: InputEvent) -> void:
	if _game_state == null:
		return

	# Scroll zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = (_camera.zoom * 1.1).clampf(0.3, 3.0) * Vector2.ONE
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = (_camera.zoom * 0.9).clampf(0.3, 3.0) * Vector2.ONE

	# Keyboard commands
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				_try_siege()
			KEY_G:
				_try_capture_neutral()
			KEY_R:
				_try_split()
			KEY_ESCAPE:
				_deselect_all()


# --- Selection ---

var _selected_city_id: int = -1
var _selected_stack_id: int = -1


func _on_city_clicked(city_id: int) -> void:
	if _game_state == null:
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

	# Select the city and the first player stack there
	_selected_city_id = city_id
	_selected_stack_id = -1

	var stacks := _game_state.get_stacks_at_city(PLAYER_ID, city_id)
	if not stacks.is_empty():
		_selected_stack_id = (stacks[0] as UnitStack).id

	_hex_map.set_selection(_selected_city_id, _selected_stack_id)
	_hex_map.queue_redraw()
	_update_stack_info()


func _deselect_all() -> void:
	_selected_city_id = -1
	_selected_stack_id = -1
	_hex_map.set_selection(-1, -1)
	_hex_map.queue_redraw()
	_stack_info.visible = false


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
	if _selected_stack_id < 0:
		return
	_game_state.submit_command({
		"type": "start_siege",
		"player_id": PLAYER_ID,
		"stack_id": _selected_stack_id,
	})
	_hex_map.queue_redraw()


func _try_capture_neutral() -> void:
	if _selected_stack_id < 0:
		return
	_game_state.submit_command({
		"type": "capture_neutral",
		"player_id": PLAYER_ID,
		"stack_id": _selected_stack_id,
	})
	_hex_map.queue_redraw()


func _try_split() -> void:
	if _selected_stack_id < 0:
		return
	var stack := _game_state.get_stack(_selected_stack_id)
	if stack == null:
		return
	# Default split: take half infantry (rounded down)
	var inf_split: int = stack.infantry_count / 2
	var cav_split: int = stack.cavalry_count / 2
	var art_split: int = stack.artillery_count / 2
	if inf_split + cav_split + art_split <= 0:
		return
	_game_state.submit_command({
		"type": "split_stack",
		"player_id": PLAYER_ID,
		"stack_id": _selected_stack_id,
		"infantry": inf_split,
		"cavalry": cav_split,
		"artillery": art_split,
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


# --- Signal Handlers ---

func _on_city_captured(city_id: int, new_owner: int) -> void:
	_hex_map.queue_redraw()


func _on_siege_started(city_id: int, _attacker: int) -> void:
	_hex_map.queue_redraw()


func _on_battle_started(city_id: int) -> void:
	_hex_map.queue_redraw()


func _on_victory(winner_id: int) -> void:
	var player_name: String = "Unknown"
	for player in _scenario_data.get("players", []):
		if int(player["id"]) == winner_id:
			player_name = player.get("name", "Player %d" % winner_id)
			break
	print("VICTORY: %s wins!" % player_name)


func _on_production_completed(_city_id: int, _unit_type: String) -> void:
	_hex_map.queue_redraw()


func _on_stack_arrived(_stack_id: int, _city_id: int) -> void:
	_hex_map.queue_redraw()
