extends Control
@onready var new_game_button=%NewGame
func _ready():
	new_game_button.pressed.connect(_on_new_game_button_pressed)
	SceneManager.transition_out_completed.connect(_on_transition_out_completed, CONNECT_ONE_SHOT)

func _on_new_game_button_pressed():
	SceneManager.transition_out()

func _on_transition_out_completed():
	SceneManager.change_scene("res://Dialogue.tscn")
