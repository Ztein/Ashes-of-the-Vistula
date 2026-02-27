extends HBoxContainer
## Top-bar HUD showing supply, orders, dominance, and game state.

@onready var _supply_label: Label = $SupplyLabel
@onready var _orders_label: Label = $OrdersLabel
@onready var _dominance_label: Label = $DominanceLabel


func update_display(cmd_info: Dictionary, supply_info: Dictionary, game_state: GameState) -> void:
	var current_supply: int = supply_info.get("current", 0)
	var supply_cap: int = supply_info.get("cap", 0)
	_supply_label.text = "Supply: %d/%d" % [current_supply, supply_cap]

	var current_orders: float = cmd_info.get("current_orders", 0.0)
	var order_cap: int = cmd_info.get("order_cap", 0)
	_orders_label.text = "Orders: %.1f/%d" % [current_orders, order_cap]

	if game_state.is_game_over():
		_dominance_label.text = "GAME OVER"
	else:
		_dominance_label.text = "Tick: %d" % game_state.get_tick_count()
