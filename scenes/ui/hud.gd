extends VBoxContainer
## Top-bar HUD showing stats for all players: supply, orders, cities, territory, dominance.

@onready var _player_row: HBoxContainer = $PlayerRow
@onready var _enemy_row: HBoxContainer = $EnemyRow
@onready var _dominance_label: Label = $DominanceRow/DominanceLabel

const PLAYER_ID: int = 0
const ENEMY_ID: int = 1


func update_display(cmd_info: Dictionary, supply_info: Dictionary, game_state: GameState) -> void:
	_update_player_row(_player_row, PLAYER_ID, cmd_info, supply_info, game_state, true)

	var enemy_cmd := game_state.get_command_info(ENEMY_ID)
	var enemy_supply := game_state.get_supply_info(ENEMY_ID)
	_update_player_row(_enemy_row, ENEMY_ID, enemy_cmd, enemy_supply, game_state, false)

	# Dominance
	if game_state.is_game_over():
		var winner := game_state.get_winner()
		if winner == PLAYER_ID:
			_dominance_label.text = "VICTORY!"
		else:
			_dominance_label.text = "DEFEAT"
	else:
		var p_dom := game_state.get_dominance_info(PLAYER_ID)
		var e_dom := game_state.get_dominance_info(ENEMY_ID)
		var dom_parts: PackedStringArray = []
		if p_dom.get("is_dominant", false):
			dom_parts.append("You: %.0fs" % p_dom.get("timer_remaining", 0.0))
		if e_dom.get("is_dominant", false):
			dom_parts.append("Enemy: %.0fs" % e_dom.get("timer_remaining", 0.0))
		if dom_parts.is_empty():
			_dominance_label.text = "Dominance: --"
		else:
			_dominance_label.text = "Dominance: " + " | ".join(dom_parts)


func _update_player_row(row: HBoxContainer, player_id: int, cmd_info: Dictionary, supply_info: Dictionary, game_state: GameState, is_local: bool) -> void:
	var label_node: Label = row.get_child(0) as Label
	var prefix := "You" if is_local else "Enemy"

	var current_supply: int = supply_info.get("current", 0)
	var supply_cap: int = supply_info.get("cap", 0)

	var total_cities: int = game_state.get_total_city_count()
	var owned_cities: int = game_state.count_owned_cities(player_id)

	var total_hexes: int = game_state.get_total_hex_count()
	var player_hexes: int = game_state.get_territory_hex_count(player_id)
	var territory_pct: float = 0.0
	if total_hexes > 0:
		territory_pct = (float(player_hexes) / float(total_hexes)) * 100.0

	var text := "%s:  Units: %d/%d  |  Cities: %d/%d  |  Territory: %.0f%%" % [
		prefix, current_supply, supply_cap, owned_cities, total_cities, territory_pct
	]

	if is_local:
		var current_orders: float = cmd_info.get("current_orders", 0.0)
		var order_cap: int = cmd_info.get("order_cap", 0)
		var regen_rate: float = cmd_info.get("regen_rate", 0.0)
		text += "  |  Orders: %.1f/%d (+%.2f/s)" % [current_orders, order_cap, regen_rate]

	label_node.text = text
