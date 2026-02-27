extends PanelContainer
## In-game pause menu. Escape toggles visibility.
## Options: Resume, Restart, Give Up (with confirmation), Quit.

signal resume_requested
signal restart_requested
signal give_up_confirmed
signal quit_requested

@onready var _main_buttons: VBoxContainer = $VBoxContainer/MainButtons
@onready var _confirm_panel: VBoxContainer = $VBoxContainer/ConfirmPanel
@onready var _confirm_label: Label = $VBoxContainer/ConfirmPanel/ConfirmLabel


func _ready() -> void:
	_main_buttons.get_node("ResumeBtn").pressed.connect(func(): resume_requested.emit())
	_main_buttons.get_node("RestartBtn").pressed.connect(func(): restart_requested.emit())
	_main_buttons.get_node("GiveUpBtn").pressed.connect(_show_give_up_confirm)
	_main_buttons.get_node("QuitBtn").pressed.connect(func(): quit_requested.emit())
	_confirm_panel.get_node("YesBtn").pressed.connect(_on_give_up_yes)
	_confirm_panel.get_node("NoBtn").pressed.connect(_on_give_up_no)
	_confirm_panel.visible = false


func show_menu() -> void:
	_confirm_panel.visible = false
	_main_buttons.visible = true
	visible = true


func hide_menu() -> void:
	visible = false


func _show_give_up_confirm() -> void:
	_main_buttons.visible = false
	_confirm_panel.visible = true
	_confirm_label.text = "Are you sure you want to give up?"


func _on_give_up_yes() -> void:
	_confirm_panel.visible = false
	visible = false
	give_up_confirmed.emit()


func _on_give_up_no() -> void:
	_confirm_panel.visible = false
	_main_buttons.visible = true
