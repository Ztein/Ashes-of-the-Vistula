class_name DominanceSystem
extends RefCounted
## Win condition: control X% cities AND Y% territory → countdown → victory.
## Timer resets when either threshold drops below required percentage.

# player_id -> { is_dominant: bool, timer_remaining: float }
var _player_data: Dictionary = {}


func initialize_player(player_id: int, balance: Dictionary) -> void:
	var dom_config: Dictionary = balance.get("dominance", {})
	var timer_duration: float = float(dom_config.get("timer_duration", 120.0))
	_player_data[player_id] = {
		"is_dominant": false,
		"timer_remaining": timer_duration,
	}


func tick(player_id: int, delta: float, owned_city_count: int, total_cities: int,
		territory_hex_count: int, total_hexes: int, balance: Dictionary) -> Dictionary:
	if not _player_data.has(player_id):
		initialize_player(player_id, balance)

	var dom_config: Dictionary = balance.get("dominance", {})
	var city_threshold: float = float(dom_config.get("city_threshold_pct", 60))
	var territory_threshold: float = float(dom_config.get("territory_threshold_pct", 50))
	var timer_duration: float = float(dom_config.get("timer_duration", 120.0))

	var data: Dictionary = _player_data[player_id]

	# Check thresholds
	var city_pct: float = 0.0
	if total_cities > 0:
		city_pct = (float(owned_city_count) / float(total_cities)) * 100.0

	var territory_pct: float = 0.0
	if total_hexes > 0:
		territory_pct = (float(territory_hex_count) / float(total_hexes)) * 100.0

	var meets_thresholds: bool = city_pct >= city_threshold and territory_pct >= territory_threshold

	if meets_thresholds:
		data["is_dominant"] = true
		data["timer_remaining"] = float(data["timer_remaining"]) - delta

		if float(data["timer_remaining"]) <= 0.0:
			data["timer_remaining"] = 0.0
			return {
				"is_dominant": true,
				"timer_remaining": 0.0,
				"victory": true,
			}
	else:
		data["is_dominant"] = false
		data["timer_remaining"] = timer_duration

	return {
		"is_dominant": bool(data["is_dominant"]),
		"timer_remaining": float(data["timer_remaining"]),
		"victory": false,
	}


func get_info(player_id: int) -> Dictionary:
	if not _player_data.has(player_id):
		return {"is_dominant": false, "timer_remaining": 0.0}
	var data: Dictionary = _player_data[player_id]
	return {
		"is_dominant": bool(data["is_dominant"]),
		"timer_remaining": float(data["timer_remaining"]),
	}


func reset_player(player_id: int, balance: Dictionary) -> void:
	initialize_player(player_id, balance)
