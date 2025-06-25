extends CanvasLayer

signal move_selected
signal end_turn_selected

@onready var move_button = $Panel/VBoxContainer/Move
@onready var end_turn_button = $"Panel/VBoxContainer/End Turn"

func _ready():
	visible = false
	
	move_button.pressed.connect(func():
		visible = false
		move_selected.emit()
	)

	end_turn_button.pressed.connect(func():
		visible = false
		end_turn_selected.emit()
	)

func open():
	visible = true

func close():
	visible = false

func disable_move_button():
	move_button.disabled = true

func enable_move_button():  # ← أضفنا دي لحل الخطأ
	move_button.disabled = false
