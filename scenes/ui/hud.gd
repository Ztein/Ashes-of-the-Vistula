extends HBoxContainer
## Top-bar HUD showing supply, orders, dominance timer, city count, territory %.

@onready var _supply_label: Label = $SupplyLabel
@onready var _orders_label: Label = $OrdersLabel
@onready var _cities_label: Label = $CitiesLabel
@onready var _territory_label: Label = $TerritoryLabel
@onready var _dominance_label: Label = $DominanceLabel

const PLAYER_ID: int = 0


func update_display(cmd_info: Dictionary, supply_info: Dictionary, game_state: GameState) -> void:
	# Supply
	var current_supply: int = supply_info.get("current", 0)
	var supply_cap: int = supply_info.get("cap", 0)
	_supply_label.text = "Units: %d/%d" % [current_supply, supply_cap]

	# Orders
	var current_orders: float = cmd_info.get("current_orders", 0.0)
	var order_cap: int = cmd_info.get("order_cap", 0)
	var regen_rate: float = cmd_info.get("regen_rate", 0.0)
	_orders_label.text = "Orders: %.1f/%d (+%.2f/s)" % [current_orders, order_cap, regen_rate]

	# Cities
	var total_cities: int = game_state.get_total_city_count()
	var owned_cities: int = game_state.count_owned_cities(PLAYER_ID)
	_cities_label.text = "Cities: %d/%d" % [owned_cities, total_cities]

	# Territory
	var total_hexes: int = game_state.get_total_hex_count()
	var player_hexes: int = game_state.get_territory_hex_count(PLAYER_ID)
	var territory_pct: float = 0.0
	if total_hexes > 0:
		territory_pct = (float(player_hexes) / float(total_hexes)) * 100.0
	_territory_label.text = "Territory: %.0f%%" % territory_pct

	# Dominance
	if game_state.is_game_over():
		var winner := game_state.get_winner()
		if winner == PLAYER_ID:
			_dominance_label.text = "VICTORY!"
		else:
			_dominance_label.text = "DEFEAT"
	else:
		var dom_info := game_state.get_dominance_info(PLAYER_ID)
		if dom_info.get("is_dominant", false):
			var remaining: float = dom_info.get("timer_remaining", 0.0)
			_dominance_label.text = "Dominance: %.0fs" % remaining
		else:
			_dominance_label.text = "Dominance: --"
