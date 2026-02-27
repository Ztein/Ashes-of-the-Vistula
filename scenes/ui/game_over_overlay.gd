extends PanelContainer
## Victory/Defeat overlay. Shows result and restart/menu buttons.

signal restart_requested
signal menu_requested

@onready var _result_label: Label = $VBoxContainer/ResultLabel
@onready var _restart_btn: Button = $VBoxContainer/ButtonRow/RestartBtn
@onready var _menu_btn: Button = $VBoxContainer/ButtonRow/MenuBtn


func _ready() -> void:
	_restart_btn.pressed.connect(func(): restart_requested.emit())
	_menu_btn.pressed.connect(func(): menu_requested.emit())


func show_victory() -> void:
	_result_label.text = "VICTORY!"
	visible = true


func show_defeat() -> void:
	_result_label.text = "DEFEAT"
	visible = true
