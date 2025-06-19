extends Control

func _ready():
	pass
 


func _on_new_game_pressed() -> void:
	var NextScene=load("res://Dialogue.tscn")
	await Fade.fade_out()
	get_tree().change_scene_to_packed(NextScene)
	#await get_tree().process_frame
	Fade.fade_in()
