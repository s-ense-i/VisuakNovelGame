extends CanvasLayer

@onready var fade_rect = $ColorRect
@onready var anim =$ColorRect/AnimationTree

signal fade_finished

func fade_out():
	anim.play("fade_out")
	await anim.animation_finished
	emit_signal("fade_finished")

func fade_in():
	anim.play("fade_in")
