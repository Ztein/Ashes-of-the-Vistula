extends PanelContainer
## Displays selected stack details: unit composition, DPS, siege damage, speed.

@onready var _label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var _city_label: Label = $MarginContainer/VBoxContainer/CityLabel


func update_display(stack: UnitStack, balance: Dictionary) -> void:
	if stack == null or stack.is_empty():
		visible = false
		return

	var lines: PackedStringArray = []
	lines.append("Stack #%d" % stack.id)
	lines.append("---")
	if stack.infantry_count > 0:
		lines.append("Infantry: %d" % stack.infantry_count)
	if stack.cavalry_count > 0:
		lines.append("Cavalry: %d" % stack.cavalry_count)
	if stack.artillery_count > 0:
		lines.append("Artillery: %d" % stack.artillery_count)
	lines.append("Total: %d units" % stack.total_units())
	lines.append("---")
	lines.append("DPS: %.1f" % stack.total_dps(balance))
	lines.append("Siege: %.1f" % stack.total_siege_damage(balance))
	lines.append("Speed: %.1f" % stack.movement_speed(balance))

	if stack.is_moving:
		lines.append("---")
		lines.append("Moving... %.0f%%" % (stack.move_progress * 100.0))

	_label.text = "\n".join(lines)
