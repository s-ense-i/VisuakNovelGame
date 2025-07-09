# TurnMessage.gd
extends Control

@onready var label = $Label
@onready var anim = $AnimationPlayer

func show_message(text: String) -> void:
	label.text = text
	anim.play("show")
	await anim.animation_finished
