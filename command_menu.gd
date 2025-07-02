extends CanvasLayer

signal move_selected
signal end_turn_selected

@onready var move_button = $Panel/VBoxContainer/Move
@onready var end_turn_button = $"Panel/VBoxContainer/End Turn"

func _ready():
	visible = false
	
	move_button.pressed.connect(_on_move_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

func _on_move_pressed():
	visible = false
	move_selected.emit()

func _on_end_turn_pressed():
	visible = false
	end_turn_selected.emit()

func open():
	visible = true

func close():
	visible = false

func disable_move_button():
	move_button.disabled = true

func enable_move_button():
	move_button.disabled = false
