extends Control
## Main menu with Start Game button.

@onready var _start_btn: Button = $VBoxContainer/StartButton
@onready var _title_label: Label = $VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $VBoxContainer/SubtitleLabel


func _ready() -> void:
	_start_btn.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
