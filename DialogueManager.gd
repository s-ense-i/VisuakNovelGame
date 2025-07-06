# DialogueManager.gd - A global singleton for handling all dialogue.
extends Node

# --- Signals ---
# These signals will tell the active scene what to do visually.
signal dialogue_started
signal dialogue_ended
signal line_updated(speaker_name, text_line)
signal choices_presented(choices)
signal character_command(command, character_name, animation, new_character_name)
signal location_changed(background_path)
signal hide_ui_elements
signal request_scene_transition(scene_path)


# --- State Variables ---
var dialogue_lines: Array = []
var dialogue_index: int = 0
var is_dialogue_active: bool = false
var is_waiting_for_choice: bool = false


func _input(event):
	# Only process input if a dialogue is running
	if not is_dialogue_active or is_waiting_for_choice:
		return

	# Handle advancing the dialogue
	if event.is_action_pressed("next_line"):
		# Here, you would normally check if the text animation is finished.
		# For now, we'll just advance the line. In your DialogueUi, you'd
		# connect a signal to let the manager know the text is fully displayed.
		# Let's assume for now the DialogueUi will handle skipping the animation.
		# If the UI is still animating, it should just skip the animation instead of advancing.
		# This part requires your DialogueUi to emit a signal like "text_animation_finished".
		# For simplicity, we advance directly.
		advance_line()

func start_dialogue(file_path: String):
	"""Public function to start a new dialogue from any scene."""
	dialogue_lines = load_dialogue(file_path)
	if dialogue_lines.is_empty():
		is_dialogue_active = false
		return

	dialogue_index = 0
	is_dialogue_active = true
	is_waiting_for_choice = false
	emit_signal("dialogue_started")
	process_current_line()

func advance_line():
	"""Moves to the next line of dialogue."""
	dialogue_index += 1
	process_current_line()

func select_choice(anchor: String):
	"""Called by the UI when a player selects a choice."""
	if not is_waiting_for_choice:
		return

	is_waiting_for_choice = false
	var anchor_pos = get_anchor_position(anchor)
	if anchor_pos != -1:
		dialogue_index = anchor_pos
		process_current_line()
	else:
		printerr("DialogueManager: Couldn't find anchor '" + anchor + "'")


func process_current_line():
	if dialogue_index >= dialogue_lines.size():
		end_dialogue()
		return

	var line = dialogue_lines[dialogue_index]

	# --- Handle Special Commands ---
	if line.has("end"):
		end_dialogue()
		return

	if line.has("next_scene"):
		emit_signal("request_scene_transition", "res://project assets/Story/" + line["next_scene"] + ".json")
		# The scene manager should handle the actual transition.
		# We stop processing here.
		is_dialogue_active = false
		return
		
	if line.has("location"):
		var background_file = "res://project assets/Assets only for a demo/Backgrounds/" + line["location"] + ".png"
		emit_signal("location_changed", background_file)
		advance_line() # Immediately process the next line
		return

	if line.has("goto"):
		var anchor_pos = get_anchor_position(line["goto"])
		if anchor_pos != -1:
			dialogue_index = anchor_pos
			process_current_line()
		return

	if line.has("anchor"):
		advance_line() # Anchors are just markers, skip to the next line
		return
		
	# --- Handle Character Commands ---
	if line.has("hide_character"):
		emit_signal("character_command", "hide", line["hide_character"], "", "")

	if line.has("show_only"):
		emit_signal("character_command", "show_only", line["show_only"], line.get("animation", "idle"), "")

	if line.has("replace_character"):
		var new_char = line.get("new_character", line.get("speaker", ""))
		emit_signal("character_command", "replace", line["replace_character"], line.get("animation", "idle"), new_char)
		
	# --- Handle Choices ---
	if line.has("choices"):
		is_waiting_for_choice = true
		emit_signal("choices_presented", line["choices"])
		# Stop processing until a choice is made
		return
	
	# --- Handle Regular Dialogue Line ---
	var speaker = line.get("speaker", "Narration")
	var text = line.get("text", "")
	var animation = line.get("animation", "idle")
	
	# If not narration, ensure the speaking character is shown
	if speaker != "Narration":
		emit_signal("character_command", "show", speaker, animation, "")
	
	emit_signal("line_updated", speaker, text)


func end_dialogue():
	"""Cleans up and signals that the dialogue is over."""
	print("Dialogue ended.")
	is_dialogue_active = false
	dialogue_lines.clear()
	emit_signal("hide_ui_elements")
	emit_signal("dialogue_ended")

# --- Utility Functions (from your original script) ---
func load_dialogue(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		printerr("Error: The file doesn't exist ", file_path)
		return []
	var file = FileAccess.open(file_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json_content = JSON.parse_string(content)
	if json_content == null:
		printerr("Failed to parse json from file ", file_path)
		return []
	return json_content

func get_anchor_position(anchor: String) -> int:
	for i in range(dialogue_lines.size()):
		if dialogue_lines[i].has("anchor") and dialogue_lines[i]["anchor"] == anchor:
			return i
	printerr("Couldn't find anchor '" + anchor + "'")
	return -1
