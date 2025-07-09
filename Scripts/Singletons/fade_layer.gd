# fade.gd - Modified with speed control
extends CanvasLayer
@onready var fade_rect = $ColorRect
@onready var anim = $ColorRect/AnimationTree
signal fade_finished
var target_scene: String = ""

# Add speed control variables
var fade_speed: float = 1.0  # 1.0 = normal speed, 0.5 = half speed (slower), 2.0 = double speed

func fade_out():
	# Get all nodes in the scene that should fade
	var fade_nodes = get_tree().get_nodes_in_group("FadeGroup")
	for node in fade_nodes:
		if node is CanvasItem:
			node.modulate.a = 0  # Make them transparent immediately
	
	# Set the animation speed
	anim.set("parameters/TimeScale/scale", fade_speed)
	anim.play("fade_out")
	await anim.animation_finished
	emit_signal("fade_finished")

func fade_in():
	# Set the animation speed
	anim.set("parameters/TimeScale/scale", fade_speed)
	anim.play("fade_in")
	await anim.animation_finished
	emit_signal("fade_finished")

func transition_to_scene(scene_path: String):
	target_scene = scene_path
	fade_out()
	await fade_finished
	get_tree().change_scene_to_file(target_scene)
	fade_in()

# Optional: Add a function to change fade speed
func set_fade_speed(speed: float):
	fade_speed = speed
