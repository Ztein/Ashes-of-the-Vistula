extends PanelContainer
## Runtime balance tuning panel. Toggle with F12.
## All balance.json values editable. Reload/export JSON. Reset match.

signal reset_requested
signal balance_changed(new_balance: Dictionary)

var _balance: Dictionary = {}
var _fields: Dictionary = {}  # "section.key" -> Control
var _game_state: GameState

@onready var _scroll: ScrollContainer = $VBoxContainer/ScrollContainer
@onready var _content: VBoxContainer = $VBoxContainer/ScrollContainer/Content
@onready var _state_label: Label = $VBoxContainer/StateLabel
@onready var _btn_reload: Button = $VBoxContainer/ButtonRow/ReloadBtn
@onready var _btn_apply: Button = $VBoxContainer/ButtonRow/ApplyBtn
@onready var _btn_export: Button = $VBoxContainer/ButtonRow/ExportBtn
@onready var _btn_reset: Button = $VBoxContainer/ButtonRow/ResetBtn


func _ready() -> void:
	_btn_reload.pressed.connect(_on_reload)
	_btn_apply.pressed.connect(_on_apply)
	_btn_export.pressed.connect(_on_export)
	_btn_reset.pressed.connect(_on_reset)


func setup(balance: Dictionary, game_state: GameState) -> void:
	_balance = balance.duplicate(true)
	_game_state = game_state
	_build_ui()
	_update_state_display()


func _build_ui() -> void:
	# Clear existing content
	for child in _content.get_children():
		child.queue_free()
	_fields.clear()

	# Build sections from balance data
	var sections := ["units", "cities", "supply", "command", "dominance", "simulation", "ai"]
	for section in sections:
		if not _balance.has(section):
			continue
		_add_section(section, _balance[section])


func _add_section(section_name: String, data: Variant) -> void:
	var header := Label.new()
	header.text = "=== %s ===" % section_name.to_upper()
	header.add_theme_font_size_override("font_size", 14)
	_content.add_child(header)

	if data is Dictionary:
		var dict: Dictionary = data
		for key in dict:
			var value = dict[key]
			if value is Dictionary:
				# Nested (e.g. units.infantry)
				var sub_header := Label.new()
				sub_header.text = "  [%s]" % key
				_content.add_child(sub_header)
				var sub_dict: Dictionary = value
				for sub_key in sub_dict:
					_add_field("%s.%s.%s" % [section_name, key, sub_key], sub_key, sub_dict[sub_key])
			else:
				_add_field("%s.%s" % [section_name, key], key, value)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_content.add_child(spacer)


func _add_field(field_key: String, label_text: String, value: Variant) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)

	var label := Label.new()
	label.text = "    %s:" % label_text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)

	var input := LineEdit.new()
	input.text = str(value)
	input.custom_minimum_size = Vector2(80, 0)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)

	_content.add_child(row)
	_fields[field_key] = input


func _read_fields_to_balance() -> Dictionary:
	var result: Dictionary = _balance.duplicate(true)

	for field_key in _fields:
		var input: LineEdit = _fields[field_key]
		var parts: PackedStringArray = field_key.split(".")
		var value_str: String = input.text

		# Parse to number if possible
		var value: Variant = value_str
		if value_str.is_valid_float():
			value = float(value_str)
			# Keep as int if it looks like one
			if value_str.is_valid_int():
				value = int(value_str)

		# Set in the nested dictionary
		if parts.size() == 2:
			result[parts[0]][parts[1]] = value
		elif parts.size() == 3:
			result[parts[0]][parts[1]][parts[2]] = value

	return result


func _on_reload() -> void:
	var loader := ConfigLoader.new()
	var fresh := loader.load_balance()
	if fresh.is_empty():
		return
	_balance = fresh
	# Update all field values
	for field_key in _fields:
		var parts: PackedStringArray = field_key.split(".")
		var value: Variant
		if parts.size() == 2:
			value = _balance.get(parts[0], {}).get(parts[1], "")
		elif parts.size() == 3:
			value = _balance.get(parts[0], {}).get(parts[1], {}).get(parts[2], "")
		(_fields[field_key] as LineEdit).text = str(value)


func _on_apply() -> void:
	var new_balance := _read_fields_to_balance()
	_balance = new_balance
	balance_changed.emit(new_balance)


func _on_export() -> void:
	var new_balance := _read_fields_to_balance()
	var json_string := JSON.stringify(new_balance, "  ")
	var file := FileAccess.open("res://data/balance.json", FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		file.close()
		print("Admin: exported balance.json")


func _on_reset() -> void:
	reset_requested.emit()


func update_state_display() -> void:
	_update_state_display()


func _update_state_display() -> void:
	if _game_state == null or _state_label == null:
		return

	var lines: PackedStringArray = []
	lines.append("--- Derived State ---")

	for player_id in [0, 1]:
		var cmd := _game_state.get_command_info(player_id)
		var supply := _game_state.get_supply_info(player_id)
		var hex_count := _game_state.get_territory_hex_count(player_id)
		var city_count := _game_state.count_owned_cities(player_id)
		var dom := _game_state.get_dominance_info(player_id)

		lines.append("P%d: Cities=%d Supply=%d/%d Orders=%.1f/%d Territory=%d Dom=%s" % [
			player_id, city_count,
			supply.get("current", 0), supply.get("cap", 0),
			cmd.get("current_orders", 0.0), cmd.get("order_cap", 0),
			hex_count,
			"%.0fs" % dom.get("timer_remaining", 0.0) if dom.get("is_dominant", false) else "No",
		])

	lines.append("Tick: %d  Game Over: %s" % [
		_game_state.get_tick_count(),
		"Yes (P%d wins)" % _game_state.get_winner() if _game_state.is_game_over() else "No",
	])

	_state_label.text = "\n".join(lines)
