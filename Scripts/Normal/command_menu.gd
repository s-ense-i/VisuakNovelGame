extends CanvasLayer

signal move_selected(player_name: String)
signal attack_selected(player_name: String)
signal end_turn_selected

@onready var move_button = $Panel/VBoxContainer/Move
@onready var end_turn_button = $"Panel/VBoxContainer/End Turn"
@onready var attack_button = $Panel/VBoxContainer/Attack

var current_player_name: String = ""

func _ready():
	visible = false
	
	move_button.pressed.connect(_on_move_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func _on_move_pressed():
	visible = false
	move_selected.emit(current_player_name)

func _on_attack_pressed():
	visible = false
	attack_selected.emit(current_player_name)
	
func _on_end_turn_pressed():
	visible = false
	end_turn_selected.emit()

func show_for_player(player_name: String):
	current_player_name = player_name
	visible = true

func open():
	visible = true

func close():
	visible = false

func disable_move_button():
	move_button.disabled = true

func enable_move_button():
	move_button.disabled = false
