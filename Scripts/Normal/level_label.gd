extends Label

@onready var level_label = $"."
var level_displayed := 1

func _ready():
	animate_level_up(1, 3)

func animate_level_up(from_level: int, to_level: int):
	level_displayed = from_level
	level_label.text = str(level_displayed)

	var tween := create_tween()
	tween.tween_method(update_level_display, from_level, to_level, 3.0)

func update_level_display(value: float):
	level_displayed = round(value)
	level_label.text = str(level_displayed)
